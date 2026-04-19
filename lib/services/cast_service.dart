/* Cast Service

   Handles casting the live radio stream to Chromecast devices.

   Uses flutter_chrome_cast to load the radio stream URL
   onto a connected Cast device with metadata.
*/

import 'package:flutter_chrome_cast/flutter_chrome_cast.dart';
import '../constants/constants.dart';

class CastService {
  static final CastService instance = CastService._();
  CastService._();

  /// Cast the live radio stream to the connected Chromecast device.
  Future<void> castRadioStream({String? programTitle, String? imageUrl}) async {
    final images = <GoogleCastImage>[];
    if (imageUrl != null && imageUrl.isNotEmpty) {
      images.add(GoogleCastImage(url: Uri.parse(imageUrl)));
    }

    await GoogleCastRemoteMediaClient.instance.loadMedia(
      GoogleCastMediaInformationIOS(
        contentId: 'radio_apollo_live',
        streamType: CastMediaStreamType.live,
        contentUrl: Uri.parse(AppConstants.streamUrl),
        contentType: 'audio/mpeg',
        metadata: GoogleCastMusicMediaMetadata(
          title: programTitle ?? 'Radio Apollo',
          artist: 'Live',
          images: images,
        ),
      ),
      autoPlay: true,
    );
  }
}
