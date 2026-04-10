const { execSync } = require('child_process');

process.env.PGPASSWORD = 'admin';

const result = execSync(
  '"C:\\Program Files\\PostgreSQL\\17\\bin\\psql.exe" -U postgres -d ssut_gestion_documental -c "SELECT column_name, data_type, column_default FROM information_schema.columns WHERE table_name=\'usuarios\' AND column_name=\'bloqueos_acumulados\';"',
  { encoding: 'utf8' }
);

console.log(result);
