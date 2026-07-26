import 'package:flutter/foundation.dart';
import 'supabase_service.dart';

class UnsplashPhoto {
  final String id;
  final String imageUrl;
  final String altDescription;

  UnsplashPhoto({
    required this.id,
    required this.imageUrl,
    required this.altDescription,
  });
}

class UnsplashService {
  static final UnsplashService _instance = UnsplashService._internal();
  static UnsplashService get instance => _instance;
  UnsplashService._internal();

  final List<UnsplashPhoto> _fallbackPhotos = [
    UnsplashPhoto(
      id: "f1",
      imageUrl: "https://images.unsplash.com/photo-1522071820081-009f0129c71c?auto=format&fit=crop&w=800&q=80",
      altDescription: "A group of colleagues collaborating on laptops around a wooden office desk in a bright modern workspace.",
    ),
    UnsplashPhoto(
      id: "f2",
      imageUrl: "https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?auto=format&fit=crop&w=800&q=80",
      altDescription: "People dining together at an outdoor restaurant table during sunset.",
    ),
    UnsplashPhoto(
      id: "f3",
      imageUrl: "https://images.unsplash.com/photo-1501555088652-021faa106b9b?auto=format&fit=crop&w=800&q=80",
      altDescription: "A hiker standing on top of a rocky mountain peak overlooking scenic green valleys.",
    ),
    UnsplashPhoto(
      id: "f4",
      imageUrl: "https://images.unsplash.com/photo-1434030216411-0b793f4b4173?auto=format&fit=crop&w=800&q=80",
      altDescription: "A student studying with open books and a cup of coffee at a cozy library desk.",
    ),
  ];

  int _fallbackIndex = 0;

  Future<UnsplashPhoto> getRandomPhoto() async {
    if (SupabaseService.instance.isInitialized) {
      try {
        final data = await SupabaseService.instance.invokeUnsplashProxy();
        final imageUrl = data['urls']['regular'] as String;
        final altDesc = (data['alt_description'] as String?) ??
            (data['description'] as String?) ??
            "A detailed everyday life photo with people and natural surroundings.";
        final id = data['id'] as String;

        return UnsplashPhoto(
          id: id,
          imageUrl: imageUrl,
          altDescription: altDesc,
        );
      } catch (e) {
        debugPrint("Unsplash Edge Function proxy fetch error: $e");
      }
    }

    // Return next fallback photo
    final photo = _fallbackPhotos[_fallbackIndex];
    _fallbackIndex = (_fallbackIndex + 1) % _fallbackPhotos.length;
    return photo;
  }
}
