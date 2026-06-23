package com.vi5hnu.xylophone;

import android.content.ContentResolver;
import android.content.ContentValues;
import android.net.Uri;
import android.os.Build;
import android.os.Environment;
import android.provider.MediaStore;

import androidx.annotation.NonNull;

import java.io.OutputStream;

import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodChannel;

/**
 * Adds a small platform channel that saves an audio file into the shared
 * Music collection using Android's official MediaStore API (scoped storage,
 * no permission needed on Android 10+). This avoids depending on any
 * third-party storage plugin.
 */
public class MainActivity extends FlutterActivity {
    private static final String CHANNEL = "xylophone/storage";

    @Override
    public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);
        new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), CHANNEL)
                .setMethodCallHandler((call, result) -> {
                    if ("saveAudioToMusic".equals(call.method)) {
                        byte[] bytes = call.argument("bytes");
                        String fileName = call.argument("fileName");
                        result.success(saveAudioToMusic(bytes, fileName));
                    } else {
                        result.notImplemented();
                    }
                });
    }

    /**
     * Saves [bytes] as [fileName] into Music/Xylophone via MediaStore.
     * Returns a user-facing location string, or null if unsupported
     * (Android < 10, where the app-private fallback is used instead).
     */
    private String saveAudioToMusic(byte[] bytes, String fileName) {
        if (bytes == null || fileName == null) return null;
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) return null;

        try {
            ContentResolver resolver = getContentResolver();
            ContentValues values = new ContentValues();
            values.put(MediaStore.Audio.Media.DISPLAY_NAME, fileName);
            values.put(MediaStore.Audio.Media.MIME_TYPE, "audio/wav");
            values.put(MediaStore.Audio.Media.RELATIVE_PATH,
                    Environment.DIRECTORY_MUSIC + "/Xylophone");
            values.put(MediaStore.Audio.Media.IS_PENDING, 1);

            Uri collection = MediaStore.Audio.Media
                    .getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY);
            Uri item = resolver.insert(collection, values);
            if (item == null) return null;

            try (OutputStream out = resolver.openOutputStream(item)) {
                if (out == null) return null;
                out.write(bytes);
            }

            values.clear();
            values.put(MediaStore.Audio.Media.IS_PENDING, 0);
            resolver.update(item, values, null, null);
            return "Music/Xylophone";
        } catch (Exception e) {
            return null;
        }
    }
}
