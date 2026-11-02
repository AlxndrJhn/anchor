import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  Patch,
  Post,
  UseGuards,
} from '@nestjs/common';
import { AuthGuard } from '../auth/auth.guard';
import { CurrentUser } from '../auth/decorators/current-user.decorator';
import { AddonsService } from './addons.service';
import { InstallAddonDto } from './dto/install-addon.dto';
import { UpdateAddonDto } from './dto/update-addon.dto';

@Controller('api/addons')
@UseGuards(AuthGuard)
export class AddonsController {
  constructor(private readonly addons: AddonsService) {}

  @Get()
  findAll(@CurrentUser('id') userId: string) {
    return this.addons.findAll(userId);
  }

  @Post()
  install(@CurrentUser('id') userId: string, @Body() dto: InstallAddonDto) {
    return this.addons.install(userId, dto.manifest, dto.files);
  }

  @Patch(':id')
  update(
    @CurrentUser('id') userId: string,
    @Param('id') id: string,
    @Body() dto: UpdateAddonDto,
  ) {
    return this.addons.setEnabled(userId, id, dto.enabled);
  }

  @Delete(':id')
  remove(@CurrentUser('id') userId: string, @Param('id') id: string) {
    return this.addons.remove(userId, id);
  }
}
