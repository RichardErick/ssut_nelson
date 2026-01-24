using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.Tokens;
using Npgsql;
using SistemaGestionDocumental.Data;
using SistemaGestionDocumental.Models;
using SistemaGestionDocumental.Services;
using System.Text;
using System.Text.Json.Serialization;

var builder = WebApplication.CreateBuilder(args);

// Agrega los servicios .
builder.Services.AddControllers().AddJsonOptions(options =>
{
    options.JsonSerializerOptions.Converters.Add(new JsonStringEnumConverter());
});
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen(options =>
{
    options.AddSecurityDefinition("Bearer", new Microsoft.OpenApi.Models.OpenApiSecurityScheme
    {
        Name = "Authorization",
        Type = Microsoft.OpenApi.Models.SecuritySchemeType.Http,
        Scheme = "Bearer",
        BearerFormat = "JWT",
        In = Microsoft.OpenApi.Models.ParameterLocation.Header,
    });

    options.AddSecurityRequirement(new Microsoft.OpenApi.Models.OpenApiSecurityRequirement
    {
        {
            new Microsoft.OpenApi.Models.OpenApiSecurityScheme
            {
                Reference = new Microsoft.OpenApi.Models.OpenApiReference
                {
                    Type = Microsoft.OpenApi.Models.ReferenceType.SecurityScheme,
                    Id = "Bearer",
                }
            },
            new List<string>()
        }
    });
});

// Configuramos CORS - Permitir todos los orígenes localhost
builder.Services.AddCors(options =>
{
    options.AddPolicy("AllowFlutterApp",
        policy =>
        {
            policy.SetIsOriginAllowed(_ => true) // Permitir todos los orígenes en desarrollo
            .AllowAnyHeader()
            .AllowAnyMethod()
            .AllowCredentials();
        });
});

// Configuramos Postgres
var connectionString = builder.Configuration.GetConnectionString("DefaultConnection") 
    ?? "Host=localhost;Database=ssut_gestion_documental;Username=postgres;Password=postgres";

var dataSourceBuilder = new NpgsqlDataSourceBuilder(connectionString);
// Ya no necesitamos mapear el enum porque usamos text en lugar de rol_enum
var dataSource = dataSourceBuilder.Build();

builder.Services.AddDbContext<ApplicationDbContext>(options =>
    options.UseNpgsql(dataSource));

builder.Services.AddAuthorization();

var jwtIssuer = builder.Configuration["Jwt:Issuer"];
var jwtAudience = builder.Configuration["Jwt:Audience"];
var jwtKey = builder.Configuration["Jwt:Key"];

if (!string.IsNullOrWhiteSpace(jwtIssuer) &&
    !string.IsNullOrWhiteSpace(jwtAudience) &&
    !string.IsNullOrWhiteSpace(jwtKey))
{
    builder.Services
        .AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
        .AddJwtBearer(options =>
        {
            options.TokenValidationParameters = new TokenValidationParameters
            {
                ValidateIssuer = true,
                ValidateAudience = true,
                ValidateLifetime = true,
                ValidateIssuerSigningKey = true,
                ValidIssuer = jwtIssuer,
                ValidAudience = jwtAudience,
                IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(jwtKey)),
                ClockSkew = TimeSpan.FromMinutes(2),
            };
        });
}

// Registrando servicios
builder.Services.AddScoped<IDocumentoService, DocumentoService>();
builder.Services.AddScoped<IMovimientoService, MovimientoService>();
builder.Services.AddScoped<IQRCodeService, QRCodeService>();
builder.Services.AddScoped<IQRService, QRService>();
builder.Services.AddScoped<IReporteService, ReporteService>();

var app = builder.Build();

// Configuramos el pipeline de HTTP
if (app.Environment.IsDevelopment())
{
    app.UseDeveloperExceptionPage();
    app.UseSwagger();
    app.UseSwaggerUI();
}

if (!app.Environment.IsDevelopment())
{
    app.UseHttpsRedirection();
}

// CORS debe estar ANTES de cualquier otro middleware que pueda fallar
app.UseCors("AllowFlutterApp");

// Middleware de manejo de errores global DESPUÉS de CORS
app.Use(async (context, next) =>
{
    try
    {
        await next();
    }
    catch (Exception ex)
    {
        var logger = context.RequestServices.GetRequiredService<ILogger<Program>>();
        logger.LogError(ex, "Error no manejado: {Message}", ex.Message);
        
        // SIEMPRE agregar headers CORS antes de escribir la respuesta
        var origin = context.Request.Headers["Origin"].ToString();
        if (string.IsNullOrWhiteSpace(origin))
        {
            origin = context.Request.Headers["Referer"].ToString();
        }
        
        if (!string.IsNullOrWhiteSpace(origin))
        {
            try
            {
                if (!context.Response.HasStarted)
                {
                    context.Response.Headers.Remove("Access-Control-Allow-Origin");
                    context.Response.Headers.Append("Access-Control-Allow-Origin", "*");
                    context.Response.Headers.Append("Access-Control-Allow-Credentials", "true");
                    context.Response.Headers.Append("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS");
                    context.Response.Headers.Append("Access-Control-Allow-Headers", "Content-Type, Authorization");
                }
            }
            catch { }
        }
        else
        {
            // Si no hay origin, agregar headers CORS de todos modos
            if (!context.Response.HasStarted)
            {
                context.Response.Headers.Append("Access-Control-Allow-Origin", "*");
                context.Response.Headers.Append("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS");
                context.Response.Headers.Append("Access-Control-Allow-Headers", "Content-Type, Authorization");
            }
        }
        
        if (!context.Response.HasStarted)
        {
            context.Response.StatusCode = 500;
            context.Response.ContentType = "application/json";
            
            var errorResponse = new
            {
                message = app.Environment.IsDevelopment() 
                    ? $"Error: {ex.Message}" 
                    : "Error interno del servidor. Por favor, intente más tarde.",
                error = app.Environment.IsDevelopment() ? ex.ToString() : null
            };
            
            await context.Response.WriteAsJsonAsync(errorResponse);
        }
    }
});

app.UseAuthentication();
app.UseAuthorization();
app.MapControllers();

// Verificamos la conexión a la base de datos
using (var scope = app.Services.CreateScope())
{
    // AQUI SE DEFINE LOS SERVICIOS QUE SE VA A USAR EN LA APLICACION
    try
    {
        var db = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();
        var logger = scope.ServiceProvider.GetRequiredService<ILogger<Program>>();
        
        // Verificar conexión
        if (db.Database.CanConnect())
        {
            logger.LogInformation("Conexión a la base de datos exitosa");
            
            // Fix temporal para migrar la columna estado de enum a text si es necesario
            // Esto evita errores de "datatype mismatch" en PostgreSQL
            try {
                const string fixSql = @"
DO $mig$ 
BEGIN 
    -- Elimina vistas que referencian enums para permitir ALTER
    IF EXISTS (SELECT 1 FROM information_schema.views WHERE table_name = 'vista_documentos_activos') THEN
        EXECUTE 'DROP VIEW IF EXISTS vista_documentos_activos';
    END IF;
    IF EXISTS (SELECT 1 FROM information_schema.views WHERE table_name = 'vista_movimientos_activos') THEN
        EXECUTE 'DROP VIEW IF EXISTS vista_movimientos_activos';
    END IF;
    IF EXISTS (SELECT 1 FROM information_schema.views WHERE table_name = 'vista_documentos_completa') THEN
        EXECUTE 'DROP VIEW IF EXISTS vista_documentos_completa';
    END IF;

    -- Convierte columnas enum a texto (ignora si ya est
n en texto)
    BEGIN
        ALTER TABLE documentos ALTER COLUMN estado TYPE VARCHAR(50) USING estado::text;
    EXCEPTION WHEN undefined_column THEN
        NULL;
    WHEN others THEN
        RAISE;
    END;

    BEGIN
        ALTER TABLE movimientos ALTER COLUMN tipo_movimiento TYPE VARCHAR(50) USING tipo_movimiento::text;
    EXCEPTION WHEN undefined_column THEN
        NULL;
    WHEN others THEN
        RAISE;
    END;

    BEGIN
        ALTER TABLE movimientos ALTER COLUMN estado TYPE VARCHAR(50) USING estado::text;
    EXCEPTION WHEN undefined_column THEN
        NULL;
    WHEN others THEN
        RAISE;
    END;

    BEGIN
        ALTER TABLE historial_documento ALTER COLUMN estado_anterior TYPE VARCHAR(50) USING estado_anterior::text;
    EXCEPTION WHEN undefined_column THEN
        NULL;
    WHEN others THEN
        RAISE;
    END;

    BEGIN
        ALTER TABLE historial_documento ALTER COLUMN estado_nuevo TYPE VARCHAR(50) USING estado_nuevo::text;
    EXCEPTION WHEN undefined_column THEN
        NULL;
    WHEN others THEN
        RAISE;
    END;

    BEGIN
        ALTER TABLE usuarios ALTER COLUMN rol TYPE VARCHAR(30) USING rol::text;
    EXCEPTION WHEN undefined_column THEN
        NULL;
    WHEN others THEN
        RAISE;
    END;
END $mig$;

-- Opcional: eliminar types si ya no se usan
DO $cleanup$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_type WHERE typname = 'tipo_movimiento_enum') THEN
        DROP TYPE IF EXISTS tipo_movimiento_enum;
    END IF;
    IF EXISTS (SELECT 1 FROM pg_type WHERE typname = 'estado_movimiento_enum') THEN
        DROP TYPE IF EXISTS estado_movimiento_enum;
    END IF;
    IF EXISTS (SELECT 1 FROM pg_type WHERE typname = 'estado_documento_enum') THEN
        DROP TYPE IF EXISTS estado_documento_enum;
    END IF;
    IF EXISTS (SELECT 1 FROM pg_type WHERE typname = 'rol_enum') THEN
        DROP TYPE IF EXISTS rol_enum;
    END IF;
END $cleanup$;";
                db.Database.ExecuteSqlRaw(fixSql);
            } catch (Exception ex) {
                logger.LogWarning("No se pudo ejecutar el script de corrección de tipos: {Message}", ex.Message);
            }
        }
        //aqui no deberia entrar nunca
        else
        {
            logger.LogWarning("No se puede conectar a la base de datos. Asegúrate de que PostgreSQL esté ejecutándose y la base de datos exista.");
        }
    }
    //aqui no deberia entrar nunca
    catch (Exception ex)
    {
        var logger = scope.ServiceProvider.GetRequiredService<ILogger<Program>>();
        logger.LogError(ex, "Error al verificar la conexión a la base de datos");
        // No lanzamos la excepción para que la aplicación pueda iniciar
        // La base de datos debe ser creada manualmente usando los scripts SQL
        // la bd es creado manaulmentre usando los scripts sql en la carpeta database
    }
}
//AQUI SE EJECUTA LA APLICACION EN EL PUERTO 7000
app.Run();

