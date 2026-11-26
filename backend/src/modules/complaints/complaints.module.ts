import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { COMPLAINT_PHOTO_STORAGE } from '../../core/common/tokens';
import { ComplaintsService } from './application/complaints.service';
import { ComplaintComment } from './entities/complaint-comment.entity';
import { ComplaintLike } from './entities/complaint-like.entity';
import { Complaint } from './entities/complaint.entity';
import { VercelBlobPhotoStorage } from './infrastructure/vercel-blob-photo-storage';
import { ComplaintsController } from './presentation/complaints.controller';

@Module({
  imports: [
    TypeOrmModule.forFeature([Complaint, ComplaintLike, ComplaintComment]),
  ],
  controllers: [ComplaintsController],
  providers: [
    ComplaintsService,
    { provide: COMPLAINT_PHOTO_STORAGE, useClass: VercelBlobPhotoStorage },
  ],
})
export class ComplaintsModule {}
