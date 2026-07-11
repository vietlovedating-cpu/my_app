import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

class EditVoicePromptPage extends StatefulWidget {
  final String languageCode;

  const EditVoicePromptPage({
    super.key,
    required this.languageCode,
  });

  @override
  State<EditVoicePromptPage> createState() =>
      _EditVoicePromptPageState();
}

class _EditVoicePromptPageState extends State<EditVoicePromptPage> {
  static const int _maximumRecordSeconds = 90;

  final AudioRecorder _audioRecorder = AudioRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();

  Timer? _recordTimer;

  bool _isRecording = false;
  bool _isPlaying = false;
  bool _isSaving = false;

  String? _recordedVoicePath;

  int _recordSeconds = 0;

  bool get isVi => widget.languageCode == 'vi';

  String _tr(String vi, String en) => isVi ? vi : en;

  @override
  void initState() {
    super.initState();

    _audioPlayer.onPlayerComplete.listen((_) {
      if (!mounted) return;

      setState(() {
        _isPlaying = false;
      });
    });
  }

  @override
  void dispose() {
    _recordTimer?.cancel();
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  String _formatDuration(int totalSeconds) {
    final minutes =
        (totalSeconds ~/ 60).toString().padLeft(2, '0');

    final seconds =
        (totalSeconds % 60).toString().padLeft(2, '0');

    return '$minutes:$seconds';
  }

  Future<void> _startRecording() async {
    if (_isRecording) return;

    try {
      final hasPermission =
          await _audioRecorder.hasPermission();

      if (!hasPermission) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _tr(
                'Vui lòng cho phép ứng dụng sử dụng micro.',
                'Please allow the app to use your microphone.',
              ),
            ),
          ),
        );

        return;
      }

      await _audioPlayer.stop();

      final oldPath = _recordedVoicePath;

      if (oldPath != null) {
        final oldFile = File(oldPath);

        if (await oldFile.exists()) {
          await oldFile.delete();
        }
      }

      final temporaryDirectory =
          await getTemporaryDirectory();

      final path =
          '${temporaryDirectory.path}/voice_prompt_${DateTime.now().millisecondsSinceEpoch}.m4a';

      await _audioRecorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 64000,
          sampleRate: 44100,
        ),
        path: path,
      );

      if (!mounted) return;

      setState(() {
        _recordedVoicePath = null;
        _recordSeconds = 0;
        _isPlaying = false;
        _isRecording = true;
      });

      _recordTimer?.cancel();

      _recordTimer = Timer.periodic(
        const Duration(seconds: 1),
        (timer) async {
          if (!mounted) {
            timer.cancel();
            return;
          }

          final nextSeconds = _recordSeconds + 1;

          setState(() {
            _recordSeconds = nextSeconds;
          });

          if (nextSeconds >= _maximumRecordSeconds) {
            timer.cancel();
            await _stopRecording(showMaximumMessage: true);
          }
        },
      );
    } catch (e) {
      debugPrint('START VOICE PROMPT ERROR: $e');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _tr(
              'Không thể bắt đầu thu âm.',
              'Unable to start recording.',
            ),
          ),
        ),
      );
    }
  }

  Future<void> _stopRecording({
    bool showMaximumMessage = false,
  }) async {
    if (!_isRecording) return;

    try {
      _recordTimer?.cancel();

      final path = await _audioRecorder.stop();

      if (!mounted) return;

      if (path == null || path.trim().isEmpty) {
        setState(() {
          _isRecording = false;
          _recordedVoicePath = null;
        });

        return;
      }

      final file = File(path);

      if (!await file.exists()) {
        setState(() {
          _isRecording = false;
          _recordedVoicePath = null;
        });

        return;
      }

      if (_recordSeconds < 1) {
        _recordSeconds = 1;
      }

      setState(() {
        _isRecording = false;
        _recordedVoicePath = path;
      });

      if (showMaximumMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _tr(
                'Đã đạt thời lượng tối đa 1 phút 30 giây.',
                'Maximum recording length of 1 minute 30 seconds reached.',
              ),
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('STOP VOICE PROMPT ERROR: $e');

      if (!mounted) return;

      setState(() {
        _isRecording = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _tr(
              'Không thể hoàn tất bản thu âm.',
              'Unable to finish the recording.',
            ),
          ),
        ),
      );
    }
  }

  Future<void> _playOrPauseRecording() async {
    final path = _recordedVoicePath;

    if (path == null || path.trim().isEmpty) return;

    try {
      if (_isPlaying) {
        await _audioPlayer.pause();

        if (!mounted) return;

        setState(() {
          _isPlaying = false;
        });

        return;
      }

      final file = File(path);

      if (!await file.exists()) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _tr(
                'Không tìm thấy bản thu âm.',
                'Recording not found.',
              ),
            ),
          ),
        );

        return;
      }

      await _audioPlayer.stop();
      await _audioPlayer.play(DeviceFileSource(path));

      if (!mounted) return;

      setState(() {
        _isPlaying = true;
      });
    } catch (e) {
      debugPrint('PLAY VOICE PROMPT ERROR: $e');

      if (!mounted) return;

      setState(() {
        _isPlaying = false;
      });
    }
  }

  Future<void> _deleteRecording() async {
    _recordTimer?.cancel();

    if (_isRecording) {
      await _audioRecorder.stop();
    }

    await _audioPlayer.stop();

    final path = _recordedVoicePath;

    if (path != null) {
      final file = File(path);

      if (await file.exists()) {
        await file.delete();
      }
    }

    if (!mounted) return;

    setState(() {
      _isRecording = false;
      _isPlaying = false;
      _recordedVoicePath = null;
      _recordSeconds = 0;
    });
  }

Future<void> _continueButton() async {
  final user = FirebaseAuth.instance.currentUser;
  final recordedPath = _recordedVoicePath;

  if (user == null || recordedPath == null || _isSaving) {
    return;
  }

  try {
    setState(() {
      _isSaving = true;
    });

    await _audioPlayer.stop();

    final file = File(recordedPath);

    if (!await file.exists()) {
      throw Exception('Voice Prompt file does not exist');
    }

    final storageRef = FirebaseStorage.instance
        .ref()
        .child('voice_prompts')
        .child(user.uid)
        .child('voice_prompt.m4a');

    await storageRef.putFile(
      file,
      SettableMetadata(
        contentType: 'audio/mp4',
        customMetadata: {
          'userId': user.uid,
          'durationSeconds': _recordSeconds.toString(),
        },
      ),
    );

    final audioUrl = await storageRef.getDownloadURL();

    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .set({
      'voicePromptAudioUrl': audioUrl,
      'voicePromptDuration': _recordSeconds,
      'voicePromptUpdatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _tr(
            'Đã lưu Voice Prompt.',
            'Voice Prompt saved.',
          ),
        ),
      ),
    );

    Navigator.pop(context, true);
  } on FirebaseException catch (e) {
    debugPrint('SAVE VOICE PROMPT FIREBASE ERROR: ${e.code}');
    debugPrint('SAVE VOICE PROMPT MESSAGE: ${e.message}');

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _tr(
            'Không thể lưu Voice Prompt. Vui lòng thử lại.',
            'Unable to save Voice Prompt. Please try again.',
          ),
        ),
      ),
    );
  } catch (e) {
    debugPrint('SAVE VOICE PROMPT ERROR: $e');

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _tr(
            'Không thể lưu Voice Prompt. Vui lòng thử lại.',
            'Unable to save Voice Prompt. Please try again.',
          ),
        ),
      ),
    );
  } finally {
    if (mounted) {
      setState(() {
        _isSaving = false;
      });
    }
  }
}

  @override
  Widget build(BuildContext context) {
    final hasRecording = _recordedVoicePath != null;

    return Scaffold(
      backgroundColor: const Color(0xFFFFF7FB),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFF7FB),
        elevation: 0,
        iconTheme: const IconThemeData(
          color: Color(0xFF8A2F6A),
        ),
        title: Text(
          _tr('Voice Prompt', 'Voice Prompt'),
          style: const TextStyle(
            color: Color(0xFF8A2F6A),
            fontSize: 19,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            22,
            20,
            22,
            22,
          ),
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      const SizedBox(height: 12),

                      Text(
                        _tr(
                          'Hãy để mọi người nghe giọng nói thật của bạn',
                          'Let people hear the real you',
                        ),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFF8A2F6A),
                          fontSize: 23,
                          fontWeight: FontWeight.w900,
                          height: 1.25,
                        ),
                      ),

                      const SizedBox(height: 12),

                      Text(
                        _tr(
                          'Bạn chỉ có thể thêm một Voice Prompt. Thời lượng tối đa là 1 phút 30 giây.',
                          'You can add one Voice Prompt. Maximum length is 1 minute 30 seconds.',
                        ),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.black54,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          height: 1.4,
                        ),
                      ),

                      const SizedBox(height: 30),

                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius:
                              BorderRadius.circular(22),
                          border: Border.all(
                            color: const Color(0xFFFFC7DE),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color:
                                  Colors.black.withOpacity(0.05),
                              blurRadius: 14,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Text(
                              _tr(
                                'Hãy nghe tôi nói để hiểu rõ tôi hơn nhé',
  'Listen to me to get to know me better',
                              ),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.black87,
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                height: 1.35,
                              ),
                            ),

                            const SizedBox(height: 28),

                            GestureDetector(
                              onTap: _isRecording
                                  ? _stopRecording
                                  : hasRecording
                                      ? _playOrPauseRecording
                                      : _startRecording,
                              child: Container(
                                width: 92,
                                height: 92,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: _isRecording
                                      ? const Color(0xFFE91E63)
                                      : const Color(0xFFFFE4EF),
                                  border: Border.all(
                                    color:
                                        const Color(0xFFFFB5D2),
                                    width: 2,
                                  ),
                                ),
                                child: Icon(
                                  _isRecording
                                      ? Icons.stop_rounded
                                      : hasRecording
                                          ? (_isPlaying
                                              ? Icons.pause_rounded
                                              : Icons.play_arrow_rounded)
                                          : Icons.mic_rounded,
                                  size: 44,
                                  color: _isRecording
                                      ? Colors.white
                                      : const Color(0xFFE91E63),
                                ),
                              ),
                            ),

                            const SizedBox(height: 18),

                            Text(
                              _isRecording
                                  ? _tr(
                                      'Đang thu âm',
                                      'Recording',
                                    )
                                  : hasRecording
                                      ? _tr(
                                          'Bấm để nghe lại',
                                          'Tap to listen',
                                        )
                                      : _tr(
                                          'Bấm để bắt đầu thu âm',
                                          'Tap to start recording',
                                        ),
                              style: TextStyle(
                                color: _isRecording
                                    ? const Color(0xFFE91E63)
                                    : Colors.black54,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),

                            const SizedBox(height: 10),

                            Text(
                              '${_formatDuration(_recordSeconds)} / 01:30',
                              style: const TextStyle(
                                color: Color(0xFF8A2F6A),
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                              ),
                            ),

                            const SizedBox(height: 20),

                            ClipRRect(
                              borderRadius:
                                  BorderRadius.circular(99),
                              child: LinearProgressIndicator(
                                minHeight: 7,
                                value: _recordSeconds /
                                    _maximumRecordSeconds,
                                backgroundColor:
                                    const Color(0xFFFFE4EF),
                                valueColor:
                                    const AlwaysStoppedAnimation<
                                        Color>(
                                  Color(0xFFE91E63),
                                ),
                              ),
                            ),

                            if (hasRecording) ...[
                              const SizedBox(height: 20),

                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.center,
                                children: [
                                  TextButton.icon(
                                    onPressed: _deleteRecording,
                                    icon: const Icon(
                                      Icons.refresh_rounded,
                                    ),
                                    label: Text(
                                      _tr(
                                        'Thu lại',
                                        'Record again',
                                      ),
                                    ),
                                    style: TextButton.styleFrom(
                                      foregroundColor:
                                          const Color(0xFFE91E63),
                                      textStyle: const TextStyle(
                                        fontWeight:
                                            FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 18),

              SizedBox(
  width: double.infinity,
  height: 54,
  child: ElevatedButton(
    onPressed: hasRecording &&
            !_isRecording &&
            !_isSaving
        ? _continueButton
        : null,
    style: ElevatedButton.styleFrom(
      backgroundColor: const Color(0xFFE91E63),
      disabledBackgroundColor: Colors.grey.shade300,
      foregroundColor: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
    ),
    child: _isSaving
        ? const SizedBox(
            width: 23,
            height: 23,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: Colors.white,
            ),
          )
        : Text(
            _tr('Lưu Voice Prompt', 'Save Voice Prompt'),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
  ),
),
            ],
          ),
        ),
      ),
    );
  }
}