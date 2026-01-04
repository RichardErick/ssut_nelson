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

// Configuramos CORS
builder.Services.AddCors(options =>
{
    options.AddPolicy("AllowFlutterApp",
        policy =>
        {
            policy.SetIsOriginAllowed(origin =>
                !string.IsNullOrWhiteSpace(origin)
                && Uri.TryCreate(origin, UriKind.Absolute, out var uri)
                && uri.IsLoopback)
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
app.UseCors("AllowFlutterApp");
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
            // Si la base de datos ya existe, no intentamos crearla
            // Usa migraciones para actualizar el esquema si es necesario
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

