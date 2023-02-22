import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:wechat_assets_picker/wechat_assets_picker.dart';

class VideoPreview extends StatelessWidget {
  const VideoPreview({
    super.key,
    required this.asset,
  });

  final AssetEntity asset;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<File?>(
      future: asset.originFile,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text(snapshot.error.toString()));
        }

        return snapshot.hasData
            ? VideoPreviewPlayer(file: snapshot.data!)
            : const Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    color: Colors.amber,
                    strokeWidth: 2,
                  ),
                ),
              );
      },
    );
  }
}

class VideoPreviewPlayer extends StatefulWidget {
  const VideoPreviewPlayer({
    super.key,
    required this.file,
  });

  final File file;

  @override
  State<VideoPreviewPlayer> createState() => _VideoPreviewPlayerState();
}

class _VideoPreviewPlayerState extends State<VideoPreviewPlayer> {
  late final VideoPlayerController _controller;

  @override
  void initState() {
    _controller = VideoPlayerController.file(widget.file)
      ..initialize().then((_) {
        if (!mounted) return;
        setState(() {});
      })
      ..setLooping(true)
      ..play();

    super.initState();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: _controller.value.isInitialized
          ? GestureDetector(
              onTap: () => setState(() {
                _controller.value.isPlaying
                    ? _controller.pause()
                    : _controller.play();
              }),
              child: AspectRatio(
                aspectRatio: _controller.value.aspectRatio,
                child: Stack(
                  children: [
                    VideoPlayer(_controller),
                    if (!_controller.value.isPlaying)
                      const Align(
                        child: Icon(
                          Icons.play_arrow,
                          color: Colors.white,
                          size: 100,
                        ),
                      ),
                  ],
                ),
              ),
            )
          : Container(),
    );
  }
}
