import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart' as firebase_storage;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import 'package:record/record.dart';
import 'package:audio_manager/audio_manager.dart';
import 'package:routines_app/app/home.dart';

class AddRecording extends StatefulWidget {
  final FirebaseApp app;
  final record;
  final recordKey;

  const AddRecording({Key? key, required this.app, this.record, this.recordKey})
      : super(key: key);
  @override
  _AddRecordingState createState() => _AddRecordingState();
}

class _AddRecordingState extends State<AddRecording> {
  bool _isRecording = false;
  bool _isPaused = false;
  int _recordDuration = 0;
  Timer? _timer;
  Timer? _ampTimer;
  final _audioRecorder = Record();
  bool _startPlay = false;
  String audioName =
      "Recording-" + new DateTime.now().microsecondsSinceEpoch.toString();

  final audioNameController = TextEditingController();

  final ImagePicker _picker = ImagePicker();

  String _recordingPath = "";
  String _editRecordingPath = "";
  String _editImagePath = "";
  bool audioDelete = false;
  bool uploadLoader = false;

  XFile? _imageFile;
  FirebaseFirestore firestore = FirebaseFirestore.instance;

  firebase_storage.FirebaseStorage storage =
      firebase_storage.FirebaseStorage.instance;

  @override
  void initState() {
    _isRecording = false;
    super.initState();
    // events callback

    if (widget.recordKey != null && widget.record != null) {
      audioNameController.text = widget.record['name'];
      setState(() {
        audioName = widget.record['name'];
        _editRecordingPath = widget.record['audio_url'];
        _editImagePath = widget.record['image_url'];
      });
    } else {
      audioNameController.text = audioName;
    }
    firestore = FirebaseFirestore.instanceFor(app: widget.app);

    AudioManager.instance.onEvents((events, args) {
      print(" event is $events, $args");
      if (events == AudioManagerEvents.playstatus) {
        setState(() {
          _startPlay = args;
        });
        if (args == false) {
          AudioManager.instance.release();
        }
      }
      if (AudioManagerEvents.ended == events) {
        setState(() {
          _startPlay = false;
          AudioManager.instance.release();
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ampTimer?.cancel();
    _audioRecorder.dispose();
    AudioManager.instance.release();
    super.dispose();
  }

  Widget _buildTimer() {
    final String seconds = _formatNumber(_recordDuration % 60);

    return Text('$seconds sec',
        style: TextStyle(
            fontWeight: FontWeight.bold, fontSize: 25, color: Colors.white));
  }

  String _formatNumber(int number) {
    String numberStr = number.toString();
    if (number < 10) {
      numberStr = '0' + numberStr;
    }

    return numberStr;
  }

  Future<void> _start() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        await _audioRecorder.start();
        bool isRecording = await _audioRecorder.isRecording();
        setState(() {
          _isRecording = isRecording;
          _recordDuration = 0;
          audioDelete = false;
        });

        _startTimer();
      }
    } catch (e) {
      print(e);
    }
  }

  Future<void> _stop() async {
    _timer?.cancel();
    _ampTimer?.cancel();
    final path = await _audioRecorder.stop();

    print("path is  : $path");
    setState(() {
      _recordingPath = path!;
    });

    setState(() => _isRecording = false);
  }

  void _startTimer() {
    _timer?.cancel();
    _ampTimer?.cancel();

    _timer = Timer.periodic(const Duration(seconds: 1), (Timer t) {
      setState(() => _recordDuration++);
      if (_recordDuration == 15) {
        _stop();
      }
    });

    _ampTimer =
        Timer.periodic(const Duration(milliseconds: 6000), (Timer t) async {
      setState(() {});
    });
  }

  pickImage() async {
    try {
      final pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 500,
        maxHeight: 300,
      );
      setState(() {
        _imageFile = pickedFile;
      });
      if (_editImagePath != null) {
        setState(() {
          _editImagePath = "";
        });
      }
    } catch (e) {
      print("error : $e");
    }
  }

  Future<dynamic> uploadFile(
      String filePath, String fileName, bool image) async {
    File file = File(filePath);

    try {
      var path = image ? 'images/$fileName' : 'recordings/$fileName';
      var storageRef = await firebase_storage.FirebaseStorage.instance
          .ref(path)
          .putFile(file);
      String downloadURL = await firebase_storage.FirebaseStorage.instance
          .ref(storageRef.ref.fullPath)
          .getDownloadURL();
      print("downloadURL : $downloadURL");

      return {"downloadURL": downloadURL, "fullPath": storageRef.ref.fullPath};
    } catch (e) {
      print("error : $e");
      return "";
      // e.g, e.code == 'canceled'
    }
  }

  saveRecording() async {
    CollectionReference routinesRef =
        FirebaseFirestore.instance.collection('routines_recordings');
    print("audio url : $_recordingPath");
    print("image url  : ${_imageFile?.path}");
    print("audio name : ${audioNameController.text}");
    print("file path ${_recordingPath.replaceAll(RegExp('file://'), '')}");

    setState(() {
      uploadLoader = true;
    });
    firebase_storage.FirebaseStorage storage =
        firebase_storage.FirebaseStorage.instanceFor(app: widget.app);
    var imageUrl;
    var recordingUrl;
    if (_editImagePath.isEmpty && _imageFile?.path != null) {
      try {
        if (widget.record != null && widget.record['image_path'] != null) {
          await storage.ref(widget.record['image_path']).delete();
        }
      } catch (e) {
        print("error $e");
      }
      var imageFile = _imageFile?.path.toString();
      imageUrl = await uploadFile(
          imageFile!, "image" + audioNameController.text, true);
    }

    if (_editRecordingPath.isEmpty && _recordingPath != null) {
      try {
        if (widget.record != null && widget.record['recorder_path'] != null) {
          await storage.ref(widget.record['recorder_path']).delete();
        }
      } catch (e) {
        print("error $e");
      }
      recordingUrl = await uploadFile(
          _recordingPath.replaceAll(RegExp('file://'), ''),
          audioNameController.text,
          false);
    }

    if (widget.record != null) {
      print("image : ${_editImagePath.isNotEmpty ? _editImagePath : imageUrl}");
      routinesRef.doc(widget.recordKey).update({
        'name': audioNameController.text,
        'image_url': _editImagePath.isNotEmpty
            ? _editImagePath
            : imageUrl['downloadURL'],
        'audio_url': _editRecordingPath.isNotEmpty
            ? _editRecordingPath
            : recordingUrl['downloadURL'],
        'image_path': _editImagePath.isNotEmpty
            ? widget.record['image_path']
            : imageUrl['fullPath'],
        'recorder_path': _editRecordingPath.isNotEmpty
            ? widget.record['recorder_path']
            : recordingUrl['fullPath']
      }).then((value) {
        print("updated  Added");
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => Home(app: widget.app)),
        );
        setState(() {
          uploadLoader = false;
        });
      }).catchError((error) {
        print("Failed to add user: $error");
        setState(() {
          uploadLoader = false;
        });
      });
    } else {
      routinesRef.add({
        'name': audioNameController.text,
        'image_url': imageUrl['downloadURL'],
        'audio_url': recordingUrl['downloadURL'],
        'image_path': imageUrl['fullPath'],
        'recorder_path': recordingUrl['fullPath']
      }).then((value) {
        print("audio  Added");
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => Home(app: widget.app)),
        );
        setState(() {
          uploadLoader = false;
        });
      }).catchError((error) {
        print("Failed to add user: $error");
        setState(() {
          uploadLoader = false;
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    var width = MediaQuery.of(context).size.width;
    var height = MediaQuery.of(context).size.height;
    final String seconds = _formatNumber(_recordDuration % 60);
    final percentage = (int.parse(seconds) / 15).toStringAsFixed(1);

    var disable = widget.record != null
        ? widget.record != null
        : _recordingPath.isNotEmpty && _imageFile != null;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text("Add Recording"),
        backgroundColor: Colors.black12,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: <Widget>[
              SizedBox(
                height: 60,
              ),
              CircularPercentIndicator(
                radius: 100.0,
                lineWidth: 5.0,
                circularStrokeCap: CircularStrokeCap.round,
                percent: percentage != null && !audioDelete
                    ? double.parse(percentage)
                    : 0.0,
                center: Icon(
                  _recordingPath.isNotEmpty ? Icons.play_arrow : Icons.mic,
                  color: Colors.white,
                  size: 50,
                ),
                backgroundColor: Colors.white,
                progressColor: Colors.blue,
              ),
              SizedBox(
                height: 20,
              ),
              (_isRecording || _isPaused) ? _buildTimer() : Container(),
              SizedBox(
                height: 25,
              ),
              _recordingPath.isNotEmpty || _editRecordingPath.isNotEmpty
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        GestureDetector(
                          onTap: () {
                            if (!_startPlay) {
                              AudioManager.instance
                                  .start(
                                      _editRecordingPath.isNotEmpty
                                          ? _editRecordingPath
                                          : Platform.isAndroid
                                              ? 'file://' + _recordingPath
                                              : _recordingPath,
                                      "$audioName",
                                      desc: "",
                                      cover: _editImagePath != null
                                          ? _editImagePath
                                          : "assets/Golf.png")
                                  .then((err) {
                                print(err);
                              });
                              setState(() {
                                _startPlay = true;
                              });
                            } else {
                              AudioManager.instance.playOrPause();
                              setState(() {
                                _startPlay = false;
                              });
                              AudioManager.instance.release();
                            }
                          },
                          child: Container(
                            width: 70,
                            height: 45,
                            decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                color: Colors.blue),
                            child: Center(
                                child: Icon(
                                    _startPlay
                                        ? Icons.stop_circle_outlined
                                        : Icons.play_arrow_outlined,
                                    color: Colors.white,
                                    size: 30)),
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            if (AudioManager.instance.isPlaying) {
                              AudioManager.instance.release();
                            }
                            setState(() {
                              audioDelete = true;
                              _recordingPath = "";
                            });
                            if (_editRecordingPath != null) {
                              setState(() {
                                _editRecordingPath = "";
                              });
                            }
                          },
                          child: Container(
                            margin: EdgeInsets.only(left: 20),
                            width: 70,
                            height: 45,
                            decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                color: Colors.redAccent),
                            child: Center(
                                child: Icon(Icons.delete_forever_outlined,
                                    color: Colors.white, size: 25)),
                          ),
                        ),
                      ],
                    )
                  : GestureDetector(
                      onTap: () {
                        _isRecording ? _stop() : _start();
                      },
                      child: Container(
                        width: 150,
                        height: 45,
                        decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            color: Colors.blue),
                        child: Center(
                            child: Text(
                          _isRecording ? "Stop Recording" : "Start Recording",
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.bold),
                        )),
                      ),
                    ),
              SizedBox(
                height: 35,
              ),
              Padding(
                padding: const EdgeInsets.only(left: 43),
                child: Align(
                  alignment: Alignment.topLeft,
                  child: Text(
                    "Recoding name ",
                    style: TextStyle(fontSize: 18, color: Colors.white),
                  ),
                ),
              ),
              SizedBox(
                height: 5,
              ),
              Container(
                width: width * 0.8,
                child: TextField(
                  controller: audioNameController,
                  decoration: InputDecoration(
                    hintText: "name",
                    hintStyle: TextStyle(color: Colors.white),
                    enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(
                        color: Colors.blue,
                      ),
                    ),
                  ),
                  style: TextStyle(color: Colors.white),
                ),
              ),
              SizedBox(
                height: 35,
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: () {
                      if (disable && !uploadLoader) {
                        saveRecording();
                      }
                    },
                    child: Container(
                      width: width * 0.8,
                      height: 45,
                      decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          color: disable
                              ? Colors.blue
                              : Colors.blue.withOpacity(0.7)),
                      child: uploadLoader
                          ? Center(
                              child: SizedBox(
                                  height: 27,
                                  width: 27,
                                  child: CircularProgressIndicator(
                                      color: Colors.white, strokeWidth: 3)))
                          : Center(
                              child: Text(
                              "Save Recording",
                              style: TextStyle(
                                  color: disable
                                      ? Colors.white
                                      : Colors.white.withOpacity(0.7),
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold),
                            )),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
