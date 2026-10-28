import { Injectable } from '@nestjs/common';
import { InjectDataSource } from '@nestjs/typeorm';
import { DataSource } from 'typeorm';

export interface HealthReport {
  status: 'ok';
  db: 'up' | 'down';
  uptime: number;
  version: string;
}

@Injectable()
export class HealthService {
  constructor(
    @InjectDataSource() private readonly dataSource: DataSource,
  ) {}

  async check(): Promise<HealthReport> {
    let db: 'up' | 'down' = 'down';
    try {
      await this.dataSource.query('SELECT 1');
      db = 'up';
    } catch {
      db = 'down';
    }
    return {
      status: 'ok',
      db,
      uptime: Number(process.uptime().toFixed(1)),
      version: process.env.APP_VERSION ?? '1.0.0',
    };
  }
}
