function canrestart = check_save_progress() % , log_path, is_play)
global vr
canrestart = vr.logger.getWriteCounter() == 0;

