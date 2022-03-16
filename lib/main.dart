import 'dart:convert';
import 'dart:typed_data';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: MyHomePage(),
    );
  }
}

class MyHomePage extends StatelessWidget {
  const MyHomePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sound Test'),
      ),
      body: Center(
        child: FutureBuilder<Uint8List>(
          future: http.readBytes(
              Uri.parse('https://filebin.net/boffkapyqfg4licf/audio.wav')),
          builder: (context, snapshot) {
            if (snapshot.hasData) {
              final dataBuffer = snapshot.data!;
              return SoundPlayerUI(dataBuffer: dataBuffer);
            }
            return const CircularProgressIndicator();
          },
        ),
      ),
    );
  }
}

//class MyHomePage extends StatelessWidget {
//  const MyHomePage({Key? key}) : super(key: key);
//
//  @override
//  Widget build(BuildContext context) {
//    return Scaffold(
//      appBar: AppBar(
//        title: const Text('Sound Test'),
//      ),
//      body: Center(
//        child: FutureBuilder<http.Response>(
//          future: http.get(
//              Uri.parse('https://filebin.net/4i2f18nheahilka7/audio.json')),
//          builder: (context, snapshot) {
//            if (snapshot.hasData) {
//              final dataBuffer = Uint8List.fromList(
//                  List<int>.from(jsonDecode(snapshot.data!.body)['bytes']));
//              return SoundPlayerUI(dataBuffer: dataBuffer);
//            }
//            return const CircularProgressIndicator();
//          },
//        ),
//      ),
//    );
//  }
//}

class SoundPlayerUI extends StatefulWidget {
  final Uint8List dataBuffer;
  const SoundPlayerUI({
    Key? key,
    required this.dataBuffer,
  }) : super(key: key);

  @override
  State<SoundPlayerUI> createState() => _SoundPlayerUIState();
}

class _SoundPlayerUIState extends State<SoundPlayerUI> {
  late AudioPlayer _audioPlayer;
  Duration duration = const Duration();

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();

    _audioPlayer
        .setAudioSource(MyAudioSource(widget.dataBuffer))
        .then((value) => setState(() => duration = value ?? const Duration()))
        .catchError((error) {
      // catch load errors: 404, invalid url ...
      print("An error occured $error");
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  String _printDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "$twoDigitMinutes:$twoDigitSeconds";
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Row(
        children: [
          StreamBuilder<PlayerState>(
            stream: _audioPlayer.playerStateStream,
            builder: (_, snapshot) {
              final processingState = snapshot.data?.processingState;

              if (processingState == ProcessingState.loading ||
                  processingState == ProcessingState.buffering) {
                return Center(
                  child: Container(
                    margin: const EdgeInsets.all(12),
                    width: 24,
                    height: 24,
                    child: const CircularProgressIndicator(),
                  ),
                );
              }

              if (_audioPlayer.playing == false) {
                return IconButton(
                  icon: const Icon(Icons.play_arrow),
                  color: Theme.of(context).colorScheme.primary,
                  onPressed: () {
                    _audioPlayer.play();
                  },
                );
              }

              if (processingState != ProcessingState.completed) {
                return IconButton(
                  icon: const Icon(Icons.pause),
                  color: Theme.of(context).colorScheme.primary,
                  onPressed: () {
                    _audioPlayer.pause();
                  },
                );
              }

              return IconButton(
                icon: const Icon(Icons.replay),
                color: Theme.of(context).colorScheme.primary,
                onPressed: () {
                  _audioPlayer.stop();
                  _audioPlayer.seek(
                    Duration.zero,
                    index: _audioPlayer.effectiveIndices?.firstOrNull,
                  );
                  _audioPlayer.play();
                },
              );
            },
          ),
          Expanded(
            child: StreamBuilder<Duration>(
              stream: _audioPlayer.positionStream,
              builder: (context, snapshot) {
                final currentDuration = snapshot.data ?? const Duration();
                final totalDuration =
                    duration.inMilliseconds == 0 ? 1 : duration.inMilliseconds;
                final position = currentDuration.inMilliseconds / totalDuration;
                return Row(
                  children: [
                    Text(
                      '${_printDuration(currentDuration)} / ${_printDuration(duration)}',
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ClipRRect(
                        borderRadius:
                            const BorderRadius.all(Radius.circular(10)),
                        child: LinearProgressIndicator(
                          value: position,
                          minHeight: 6,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class MyAudioSource extends StreamAudioSource {
  final Uint8List _buffer;

  MyAudioSource(this._buffer) : super(tag: 'MyAudioSource');

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    // Returning the stream audio response with the parameters
    return StreamAudioResponse(
      sourceLength: _buffer.length,
      contentLength: (start ?? 0) - (end ?? _buffer.length),
      offset: start ?? 0,
      stream: Stream.fromIterable([_buffer.sublist(start ?? 0, end)]),
      contentType: 'audio/wav',
    );
  }
}
