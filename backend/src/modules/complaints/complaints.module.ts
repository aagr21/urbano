import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { ComplaintsService } from './application/complaints.service';
import { ComplaintComment } from './entities/complaint-comment.entity';
import { ComplaintLike } from './entities/complaint-like.entity';
import { Complaint } from './entities/complaint.entity';
import { ComplaintsController } from './presentation/complaints.controller';

@Module({
  imports: [
    TypeOrmModule.forFeature([Complaint, ComplaintLike, ComplaintComment]),
  ],
  controllers: [ComplaintsController],
  providers: [ComplaintsService],
})
export class ComplaintsModule {}
