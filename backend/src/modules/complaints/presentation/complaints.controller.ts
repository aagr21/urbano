import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  Post,
  Query,
  UploadedFiles,
  UseInterceptors,
} from '@nestjs/common';
import { FilesInterceptor } from '@nestjs/platform-express';
import { ApiConsumes, ApiQuery, ApiTags } from '@nestjs/swagger';
import 'multer';
import { ComplaintsService } from '../application/complaints.service';

@ApiTags('complaints')
@Controller('complaints')
export class ComplaintsController {
  constructor(private readonly service: ComplaintsService) {}

  @Get()
  @ApiQuery({ name: 'deviceKey', required: false })
  list(@Query('deviceKey') deviceKey?: string) {
    return this.service.list(deviceKey);
  }

  @Post()
  @ApiConsumes('multipart/form-data')
  @UseInterceptors(FilesInterceptor('photos', 5))
  create(
    @Body('routeId') routeId: string,
    @Body('category') category: string,
    @Body('description') description: string,
    @UploadedFiles() files: Express.Multer.File[] = []
  ) {
    return this.service.create(routeId, category, description, files);
  }

  @Post(':id/like')
  like(@Param('id') id: string, @Body('deviceKey') deviceKey: string) {
    return this.service.toggleLike(id, deviceKey, true);
  }

  @Delete(':id/like')
  @ApiQuery({ name: 'deviceKey', required: true })
  unlike(@Param('id') id: string, @Query('deviceKey') deviceKey: string) {
    return this.service.toggleLike(id, deviceKey, false);
  }

  @Get(':id/comments')
  comments(@Param('id') id: string) {
    return this.service.listComments(id);
  }

  @Post(':id/comments')
  addComment(
    @Param('id') id: string,
    @Body('deviceKey') deviceKey: string,
    @Body('body') body: string,
    @Body('authorName') authorName?: string
  ) {
    return this.service.addComment(id, deviceKey, body, authorName);
  }
}
