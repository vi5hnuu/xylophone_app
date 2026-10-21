package com.vi5hnu.xylophone;

import android.content.ContentResolver;
import android.content.ContentValues;
import android.net.Uri;
import android.os.Build;
import android.os.Environment;
import android.provider.MediaStore;
import android.util.Base64;

import androidx.annotation.NonNull;

import java.io.OutputStream;
import java.nio.charset.StandardCharsets;
import java.security.KeyFactory;
import java.security.PublicKey;
import java.security.Signature;
import java.security.spec.X509EncodedKeySpec;

import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodChannel;

/**
 * Adds two small platform channels:
 *  - storage: saves an audio file into the shared Music collection using
 *    Android's official MediaStore API (scoped storage, no permission needed
 *    on Android 10+), avoiding any third-party storage plugin.
 *  - billing: verifies a Google Play purchase signature against the app's
 *    Play licence key with the platform's own crypto (no extra library).
 */
public class MainActivity extends FlutterActivity {
    private static final String CHANNEL = "xylophone/storage";
    private static final String BILLING_CHANNEL = "xylophone/billing";

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
        new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), BILLING_CHANNEL)
                .setMethodCallHandler((call, result) -> {
                    if ("verifyPurchase".equals(call.method)) {
                        String publicKey = call.argument("publicKey");
                        String signedData = call.argument("signedData");
                        String signature = call.argument("signature");
                        result.success(verifyPurchase(publicKey, signedData, signature));
                    } else {
                        result.notImplemented();
                    }
                });
    }

    /**
     * Checks that [signedData] (the purchase's original JSON) was signed by
     * Google Play with the key matching [publicKey] (the Base64 RSA licence key
     * from Play Console). Rejects forged purchases from patched billing apps.
     */
    private boolean verifyPurchase(String publicKey, String signedData, String signature) {
        if (publicKey == null || signedData == null || signature == null) return false;
        try {
            byte[] keyBytes = Base64.decode(publicKey, Base64.DEFAULT);
            PublicKey key = KeyFactory.getInstance("RSA")
                    .generatePublic(new X509EncodedKeySpec(keyBytes));
            Signature verifier = Signature.getInstance("SHA1withRSA");
            verifier.initVerify(key);
            verifier.update(signedData.getBytes(StandardCharsets.UTF_8));
            return verifier.verify(Base64.decode(signature, Base64.DEFAULT));
        } catch (Exception e) {
            return false;
        }
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
