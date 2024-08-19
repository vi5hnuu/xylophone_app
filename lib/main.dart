import 'dart:math';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main()=>runApp(XyloPhoneApp());

class XyloPhoneApp extends StatefulWidget {
  XyloPhoneApp({super.key});
  static const List<MaterialColor> colors=[Colors.green,Colors.indigo,Colors.red,Colors.yellow,Colors.orange,Colors.purple,Colors.grey];

  @override
  State<XyloPhoneApp> createState() => _XyloPhoneAppState();
}

class _XyloPhoneAppState extends State<XyloPhoneApp> {
  final audioPlayer=AudioPlayer(playerId: Random().nextInt(1000).toString());
  List<Uri>? audioPlayersUris;

  _playAudio(int index) async{
    if(audioPlayersUris==null) return;
    await audioPlayer.stop();
    await audioPlayer.play(UrlSource((audioPlayersUris![index]).path));
  }

  @override
  void initState(){
    super.initState();
    for(int i=0;i<7;i++){
      audioPlayer.audioCache.loadAll(List.generate(7, (index) => "note${index+1}.wav")).then((asuri) => audioPlayersUris=asuri);
    }
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        resizeToAvoidBottomInset: false,
        extendBody: true,
        appBar: AppBar(
          title: const Text("XyloPhone"),
          centerTitle: true,
          backgroundColor: Colors.red,
        ),
        body: Column(
          mainAxisSize: MainAxisSize.max,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: List.generate(7, (i) => Expanded(
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: XyloPhoneApp.colors[i],
                side: BorderSide(color: XyloPhoneApp.colors[i][700]!,width: 10.0),
                shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                overlayColor: XyloPhoneApp.colors[i][700],
              ),
              child: audioPlayersUris==null ? CircularProgressIndicator(color: XyloPhoneApp.colors[i][900]?.withOpacity(0.5)) : Icon(Icons.music_note,color:XyloPhoneApp.colors[i][900],size: 50,),
              onPressed: ()=>_playAudio(i),
            ),
          ))
        )
      ),
    );
  }

  @override
  void dispose() {
    audioPlayer.dispose();
    super.dispose();
  }
}
