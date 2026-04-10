const { execSync } = require('child_process');
const fs = require('fs');
const path = require('path');

const PSQL_PATH = '"C:\\Program Files\\PostgreSQL\\17\\bin\\psql.exe"';
const DB_USER = 'postgres';
const DB_NAME = 'ssut_gestion_documental';
const SQL_FILE = path.join(__dirname, 'add_bloqueos_acumulados.sql');

console.log('=====================================================');
console.log('Aplicando cambios de bloqueo progresivo en la BD');
console.log('=====================================================');
console.log();

// Verificar que el archivo SQL existe
if (!fs.existsSync(SQL_FILE)) {
  console.error('ERROR: No se encontró el archivo SQL:', SQL_FILE);
  process.exit(1);
}

try {
  // Establecer contraseña en el ambiente
  process.env.PGPASSWORD = 'admin';
  
  console.log('Ejecutando script SQL...');
  console.log();
  
  const command = `${PSQL_PATH} -U ${DB_USER} -d ${DB_NAME} -f "${SQL_FILE}"`;
  const output = execSync(command, { 
    encoding: 'utf8',
    stdio: ['pipe', 'pipe', 'pipe']
  });
  
  console.log(output);
  console.log();
  console.log('=====================================================');
  console.log('¡Cambios aplicados exitosamente!');
  console.log('=====================================================');
  console.log();
  console.log('La columna \'bloqueos_acumulados\' ha sido agregada.');
  console.log('El sistema ahora implementará bloqueo progresivo:');
  console.log('  - 1er bloqueo: 10 minutos');
  console.log('  - 2do bloqueo: 20 minutos');
  console.log('  - 3er bloqueo: 40 minutos');
  console.log('  - Y así sucesivamente...');
  
} catch (error) {
  console.error();
  console.error('=====================================================');
  console.error('ERROR: No se pudo ejecutar el script SQL.');
  console.error('=====================================================');
  console.error();
  
  if (error.stderr) {
    console.error('Detalles del error:');
    console.error(error.stderr);
    console.error();
  }
  
  console.error('Solución alternativa manual:');
  console.error('  1. Abrir pgAdmin');
  console.error('  2. Conectarse a ssut_gestion_documental');
  console.error('  3. Abrir Query Tool');
  console.error('  4. Copiar y ejecutar el contenido de:');
  console.error('     ' + SQL_FILE);
  
  process.exit(1);
}
