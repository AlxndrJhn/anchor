import { Module } from '@nestjs/common';
import { AuthModule } from '../auth/auth.module';
import { AddonsController } from './addons.controller';
import { AddonsService } from './addons.service';

@Module({
  imports: [AuthModule],
  controllers: [AddonsController],
  providers: [AddonsService],
})
export class AddonsModule {}
