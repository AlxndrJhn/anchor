import { Module } from '@nestjs/common';
import { AuthModule } from '../auth/auth.module';
import { PictureSearchController } from './picture-search.controller';
import { PictureSearchService } from './picture-search.service';

@Module({
  imports: [AuthModule],
  controllers: [PictureSearchController],
  providers: [PictureSearchService],
  exports: [PictureSearchService],
})
export class PictureSearchModule {}
