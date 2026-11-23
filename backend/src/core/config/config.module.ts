import { Global, Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { AppConfigService } from './app-config.service';
import { validateEnvironment } from './env.validation';
import * as fs from 'node:fs';
import * as path from 'node:path';

// En Vercel no existe .env; las variables vienen por process.env.
// Solo se apunta al archivo cuando realmente existe, para que
// dotenv no lo ignore en silencio y deje process.env vacío.
const envFile = path.resolve(process.cwd(), '.env');
const hasEnvFile = fs.existsSync(envFile);

@Global()
@Module({
  imports: [
    ConfigModule.forRoot({
      isGlobal: true,
      envFilePath: hasEnvFile ? envFile : undefined,
      ignoreEnvFile: !hasEnvFile,
      cache: true,
      validate: validateEnvironment,
    }),
  ],
  providers: [AppConfigService],
  exports: [AppConfigService],
})
export class AppConfigModule {}
