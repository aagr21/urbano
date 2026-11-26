// Linter del backend (flat config de ESLint 10 + typescript-eslint).
//
// - Reglas recomendadas de JS y de TypeScript.
// - El formato es de Prettier (`npm run format`): `eslint-config-prettier`
//   apaga aquí toda regla de estilo para que no se peleen.
// - `no-console`: la API registra con el `Logger` de Nest; la consola queda
//   permitida solo en los CLIs y scripts, cuya salida ES la consola.
import js from '@eslint/js';
import prettier from 'eslint-config-prettier';
import globals from 'globals';
import tseslint from 'typescript-eslint';

export default tseslint.config(
  { ignores: ['dist/**', 'coverage/**', 'node_modules/**', 'otp-data/**'] },
  js.configs.recommended,
  ...tseslint.configs.recommended,
  {
    languageOptions: {
      globals: { ...globals.node, ...globals.jest },
    },
    rules: {
      'no-console': 'error',
      '@typescript-eslint/no-unused-vars': [
        'error',
        { argsIgnorePattern: '^_', varsIgnorePattern: '^_' },
      ],
    },
  },
  {
    files: ['src/**/*.cli.ts', 'scripts/**'],
    rules: { 'no-console': 'off' },
  },
  prettier
);
