import 'dart:async';

import 'package:audio_manager/audio_manager.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:routines_app/app/add_recording.dart';
import 'package:firebase_storage/firebase_storage.dart' as firebase_storage;

class Home extends StatefulWidget {
  final FirebaseApp app;

  const Home({Key? key, required this.app}) : super(key: key);
  @override
  _HomeState createState() => _HomeState();
}

class _HomeState extends State<Home> {
  FirebaseFirestore firestore = FirebaseFirestore.instance;

   var recodingRef;
   var selectedRecoding;
   var selectedRecordingKey;
   bool _startPlay=false;
   int countPlay=0;
  @override
  void initState() {
    // TODO: implement initState
    super.initState();

    AudioManager.instance.onEvents((events, args) {
      print(" event is $events, $args");
      if (events == AudioManagerEvents.playstatus) {
        setState(() {
          _startPlay = args;
        });
        if(args==false){
          AudioManager.instance.release();
        }
      }
      if(AudioManagerEvents.ended==events){
        if(countPlay+1<=5){
          Timer(const Duration(milliseconds: 6000), () {
            AudioManager.instance.playOrPause();
            print("called again ");
            setState(() {
              countPlay=countPlay+1;
              _startPlay = false;
              // AudioManager.instance.release();
            });
          });
        }
      }
    });
  }
  @override
  void dispose() {
    AudioManager.instance.release();
    super.dispose();
  }

  deleteSelectedRecord() async {
    if(selectedRecordingKey!=null){

        AudioManager.instance.release();
      
      firebase_storage.FirebaseStorage storage =
      firebase_storage.FirebaseStorage.instanceFor(app: widget.app);
      try{
        if(selectedRecoding['image_path']!=null){
          await storage.ref(selectedRecoding['image_path']).delete();
        }
      }catch(e){
        print("error $e");
      }
      try{
        if(selectedRecoding['recorder_path']!=null){
          await storage.ref(selectedRecoding['recorder_path']).delete();
        }
      }catch(e){
        print("error $e");
      }
      recodingRef = firestore
          .collection('routines_recordings').doc(selectedRecordingKey).delete();

      setState(() {
        selectedRecoding=null;
        selectedRecordingKey=null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    var width = MediaQuery.of(context).size.width;
    var height = MediaQuery.of(context).size.height;
    firestore = FirebaseFirestore.instanceFor(app: widget.app);
    recodingRef = firestore
        .collection('routines_recordings');
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            const Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 25, vertical: 20),
                child: Text(
                  "Feel Your Golf",
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 30,
                      color: Colors.white),
                ),
              ),
            ),
            selectedRecoding!=null ?
            Container(
              width: width * 0.9,
              height: height * 0.22,
              decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  image: DecorationImage(
                      fit: BoxFit.cover, image:  NetworkImage(selectedRecoding['image_url']))),
            ):
            Container(
              width: width * 0.9,
              height: height * 0.22,
              decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  image: DecorationImage(
                      fit: BoxFit.cover, image: const AssetImage('assets/Golf.png'))),
            ),
            const Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 25, vertical: 30),
                child: Text(
                  "Play Your Routines",
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 30,
                      color: Colors.white),
                ),
              ),
            ),
        
        Flexible(
          child: Container(
                  width: width*0.9,
                  padding:EdgeInsets.only(bottom: 70),
            child: StreamBuilder<dynamic>(
              stream: recodingRef.snapshots(),
              builder: (context,  snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text(snapshot.error.toString()),
                  );
                }

                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final data = snapshot.requireData;


                  return !snapshot.hasData?Container() :GridView.count(
                      crossAxisCount: 3,
                      crossAxisSpacing: 30.0,
                      childAspectRatio: 1 / 0.45,
                      mainAxisSpacing: 30.0,
                      children: List.generate(data.docs.length + 1, (index) {
                        return GestureDetector(
                          onTap: () {
                            if (data.docs.length != 0 &&
                                index < data.docs.length) {
                              if (selectedRecoding == null ||
                                  selectedRecoding['name'] !=
                                      data.docs[index]['name']) {
                                if (AudioManager.instance.isPlaying) {
                                  AudioManager.instance.stop();
                                }
                                AudioManager.instance
                                    .start(
                                    data.docs[index]['audio_url'],
                                    "${data.docs[index]['name']}",
                                    desc: "", cover: data.docs[index]['image_url']!=null?data.docs[index]['image_url']:"assets/Golf.png")
                                    .then((err) {
                                  print(err);
                                });
                                setState(() {
                                  _startPlay = true;
                                  countPlay = 0;
                                });
                                setState(() {
                                  selectedRecordingKey = data.docs[index].id;
                                  selectedRecoding = data.docs[index];
                                });
                              } else {
                                AudioManager.instance.playOrPause();
                                // setState(() {
                                //   _startPlay = false;
                                // });
                              }
                            }
                            else {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) =>
                                    AddRecording(app: widget.app,)),
                              );
                            }
                          },
                          child: Container(
                            padding: EdgeInsets.symmetric(horizontal: 10),
                            decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                // ignore: prefer_const_constructors
                                gradient: LinearGradient(
                                    begin: Alignment.centerLeft,
                                    end: Alignment.centerRight,
                                    // ignore: prefer_const_literals_to_create_immutables
                                    colors: [Colors.purple, Colors.blue])),
                            child: Center(
                              child: index < data.docs.length ? Text(
                                "${data.docs[index]['name']}",
                                style: TextStyle(
                                    fontSize: 12, color: Colors.white),
                                maxLines: 1,
                              ) :
                              Icon(Icons.add, color: Colors.white, size: 25,),
                            ),
                          ),
                        );
                      })
                  );
                }

      ),
          ),
        ),
          ],
        ),
      ),
      floatingActionButton:
      SizedBox(
        width:width*0.9,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            button(Icons.delete_forever_outlined, selectedRecoding!=null?Colors.redAccent:Colors.redAccent.withOpacity(0.5),(){
              if(selectedRecoding!=null) {
                deleteSelectedRecord();
              }
            }),
            const SizedBox(
              width: 40,
            ),
            button(Icons.edit_outlined, selectedRecoding!=null?Colors.blueAccent:Colors.blueAccent.withOpacity(0.5),(){
              if(selectedRecoding!=null){
                if(AudioManager.instance.isPlaying){
                  AudioManager.instance.release();
                }
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => AddRecording(app: widget.app,record:selectedRecoding,recordKey:selectedRecordingKey)),
                );
              }
            }),
          ],
        ),
      ),
    );
  }
  Widget button(icon,color,onTap){
    return  GestureDetector(
        onTap: onTap,
    child: Container(
    width: 70,
    height: 45,
    decoration: BoxDecoration(
    borderRadius: BorderRadius.circular(10),
    color: color
    ),
    child: Center(
    child: Icon(icon,color:selectedRecoding!=null?Colors.white:Colors.white.withOpacity(0.7))
    ),
    ),
    );
  }
}
