import 'dart:math';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

void main()=>runApp(const XyloPhoneApp());

class XyloPhoneApp extends StatelessWidget {
  const XyloPhoneApp({Key? key}) : super(key: key);
  static const List<MaterialColor> colors=[Colors.green,Colors.indigo,Colors.red,Colors.yellow,Colors.orange,Colors.purple,Colors.grey];
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for(int i=1;i<=7;i++)
                Expanded(
                  child: ElevatedButton(
                    style: ButtonStyle(
                      backgroundColor: MaterialStateProperty.all(colors[i-1]),
                      side: MaterialStateProperty.all(BorderSide(color: colors[i-1][700]!,width: 10.0)),
                      shape: MaterialStateProperty.all(RoundedRectangleBorder(borderRadius: BorderRadius.zero)),
                      overlayColor: MaterialStateProperty.all(colors[i-1][700]),
                    ),
                  child: Icon(Icons.music_note,color:colors[i-1][900],size: 50,),
                  onPressed: (){
                    AudioPlayer player=AudioPlayer();
                    player.audioCache.prefix="assets/";
                    player.play(AssetSource("note${i}.wav"));
                    player.dispose();
                  },
              ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
