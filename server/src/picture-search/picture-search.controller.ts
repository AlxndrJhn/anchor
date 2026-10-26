import { Body, Controller, Get, Put, Query, UseGuards } from '@nestjs/common';
import { AuthGuard } from '../auth/auth.guard';
import { CurrentUser } from '../auth/decorators/current-user.decorator';
import { PictureSearchSettingsDto } from './dto/picture-search-settings.dto';
import { PictureSearchService } from './picture-search.service';

@Controller('api/picture-search')
@UseGuards(AuthGuard)
export class PictureSearchController {
  constructor(private readonly pictureSearch: PictureSearchService) {}

  /** Notes whose pictures look like `q`, best first. */
  @Get()
  async search(@CurrentUser('id') userId: string, @Query('q') q?: string) {
    return { results: await this.pictureSearch.search(userId, q ?? '') };
  }

  /** Whether it's on for this user, and how far indexing has come. */
  @Get('status')
  status(@CurrentUser('id') userId: string) {
    return this.pictureSearch.status(userId);
  }

  @Put('settings')
  setEnabled(
    @CurrentUser('id') userId: string,
    @Body() body: PictureSearchSettingsDto,
  ) {
    return this.pictureSearch.setEnabled(userId, body.enabled);
  }
}
