import 'dart:developer';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';


void main() => runApp(const MaterialApp(home: JoinChannelAudio()));

/// JoinChannelAudio Example
class JoinChannelAudio extends StatefulWidget {
  /// Construct the [JoinChannelAudio]
  const JoinChannelAudio({Key? key}) : super(key: key);

  @override
  State<StatefulWidget> createState() => _State();
}

class _State extends State<JoinChannelAudio> {
  late final RtcEngine _engine;
  String token = "";
  int uid = 0;
  String channelName = "GamersGuardians";
  bool isJoined = false, openMicrophone = true, enableSpeakerphone = true, playEffect = false;
  bool _enableInEarMonitoring = false;
  double _recordingVolume = 100, _playbackVolume = 100, _inEarMonitoringVolume = 100;
  late TextEditingController _controller;
  ChannelProfileType _channelProfileType = ChannelProfileType.channelProfileLiveBroadcasting;
  int tokenRole = 1; // use 1 for Host/Broadcaster, 2 for Subscriber/Audience
  String serverUrl = "https://agora-token-service-production-66b2.up.railway.app"; // The base URL to your token server, for example "https://agora-token-service-production-92ff.up.railway.app"
  int tokenExpireTime = 45; // Expire time in Seconds.
  bool isTokenExpiring = false; // Set to true when the token is about to expire
  final channelTextController = TextEditingController(text: ''); // To access the TextField

  Future<void> fetchToken(int uid, String channelName, int tokenRole) async {
    // Prepare the Url
    String url = '$serverUrl/rtc/$channelName/${tokenRole.toString()}/uid/${uid.toString()}?expiry=${tokenExpireTime.toString()}';

    // Send the request
    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      // If the server returns an OK response, then parse the JSON.
      Map<String, dynamic> json = jsonDecode(response.body);
      String newToken = json['rtcToken'];
      debugPrint('Token Received: $newToken');
      // Use the token to join a channel or renew an expiring token
      setToken(newToken);
    } else {
      // If the server did not return an OK response,
      // then throw an exception.
      throw Exception(
          'Failed to fetch a token. Make sure that your server URL is valid');
    }
  }

  void setToken(String newToken) async {
    token = newToken;

    if (isTokenExpiring) {
      // Renew the token
    _engine.renewToken(token);
      isTokenExpiring = false;
      log("Token renewed");
    } else {
      // Join a channel.
      log("Token received, joining a channel...");

      await _engine.joinChannel(
        token: token,
        channelId: channelName,
        uid: uid, options: ChannelMediaOptions(
        channelProfile: _channelProfileType,
        clientRoleType: ClientRoleType.clientRoleBroadcaster,
      ),
      );
    }
  }


  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: channelName);
    _initEngine();
  }

  @override
  void dispose() {
    super.dispose();
    _dispose();
  }

  Future<void> _dispose() async {
    await _engine.leaveChannel();
    await _engine.release();
  }

  Future<void> _initEngine() async {
    _engine = createAgoraRtcEngine();
    await _engine.initialize(const RtcEngineContext(
      appId: "d776258684954df1a6813c77c705968f",
    ));

    _engine.registerEventHandler(RtcEngineEventHandler(
      onTokenPrivilegeWillExpire: (RtcConnection connection, String token) {
        log('Token expiring');
        isTokenExpiring = true;
        setState(() {
          // fetch a new token when the current token is about to expire
          fetchToken(uid, channelName, tokenRole);
        });
      },

      onError: (ErrorCodeType err, String msg) {
        log('[onError] err: $err, msg: $msg');
      },
      onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
        log('[onJoinChannelSuccess] connection: ${connection.toJson()} elapsed: $elapsed');
        setState(() {
          isJoined = true;
        });
      },
      onLeaveChannel: (RtcConnection connection, RtcStats stats) {
        log('[onLeaveChannel] connection: ${connection.toJson()} stats: ${stats.toJson()}');
        setState(() {
          isJoined = false;
        });
      },
    ));

    await _engine.enableAudio();
    await _engine.setClientRole(role: ClientRoleType.clientRoleBroadcaster);
    await _engine.setAudioProfile(
      profile: AudioProfileType.audioProfileDefault,
      scenario: AudioScenarioType.audioScenarioGameStreaming,
    );
  }

  _joinChannel() async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      await Permission.microphone.request();
    }

    await fetchToken(uid, channelName, tokenRole);
  }

  _leaveChannel() async {
    await _engine.leaveChannel();
    setState(() {
      isJoined = false;
      openMicrophone = true;
      enableSpeakerphone = true;
      playEffect = false;
      _enableInEarMonitoring = false;
      _recordingVolume = 100;
      _playbackVolume = 100;
      _inEarMonitoringVolume = 100;
    });
  }

  _switchMicrophone() async {
    // await await _engine.muteLocalAudioStream(!openMicrophone);
    await _engine.enableLocalAudio(!openMicrophone);
    setState(() {
      openMicrophone = !openMicrophone;
    });
  }

  _switchSpeakerphone() async {
    await _engine.setEnableSpeakerphone(!enableSpeakerphone);
    setState(() {
      enableSpeakerphone = !enableSpeakerphone;
    });
  }

  _switchEffect() async {
    if (playEffect) {
      await _engine.stopEffect(1);
      setState(() {
        playEffect = false;
      });
    } else {
      final path = (await _engine.getAssetAbsolutePath("assets/Sound_Horizon.mp3"))!;
      await _engine.playEffect(soundId: 1, filePath: path, loopCount: 0, pitch: 1, pan: 1, gain: 100, publish: true);
      // .then((value) {
      setState(() {
        playEffect = true;
      });
    }
  }

  _onChangeInEarMonitoringVolume(double value) async {
    _inEarMonitoringVolume = value;
    await _engine.setInEarMonitoringVolume(_inEarMonitoringVolume.toInt());
    setState(() {});
  }

  _toggleInEarMonitoring(value) async {
    try {
      await _engine.enableInEarMonitoring(enabled: value, includeAudioFilters: EarMonitoringFilterType.earMonitoringFilterNone);
      _enableInEarMonitoring = value;
      setState(() {});
    } catch (e) {
      // Do nothing
    }
  }

  @override
  Widget build(BuildContext context) {
    final channelProfileType = [
      ChannelProfileType.channelProfileLiveBroadcasting,
      ChannelProfileType.channelProfileCommunication,
    ];
    final items = channelProfileType
        .map((e) => DropdownMenuItem(
              value: e,
              child: Text(
                e.toString().split('.')[1],
              ),
            ))
        .toList();

    return Scaffold(
      body: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              TextField(
                controller: _controller,
                decoration: const InputDecoration(hintText: 'Channel ID'),
              ),
              const Text('Channel Profile: '),
              DropdownButton<ChannelProfileType>(
                  items: items,
                  value: _channelProfileType,
                  onChanged: isJoined
                      ? null
                      : (v) async {
                          setState(() {
                            _channelProfileType = v!;
                          });
                        }),
              Row(
                children: [
                  Expanded(
                    flex: 1,
                    child: ElevatedButton(
                      onPressed: isJoined ? _leaveChannel : _joinChannel,
                      child: Text('${isJoined ? 'Leave' : 'Join'} channel'),
                    ),
                  )
                ],
              ),
            ],
          ),
          Align(
              alignment: Alignment.bottomRight,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    ElevatedButton(
                      onPressed: _switchMicrophone,
                      child: Text('Microphone ${openMicrophone ? 'on' : 'off'}'),
                    ),
                    ElevatedButton(
                      onPressed: isJoined ? _switchSpeakerphone : null,
                      child: Text(enableSpeakerphone ? 'Speakerphone' : 'Earpiece'),
                    ),
                    if (!kIsWeb)
                      ElevatedButton(
                        onPressed: isJoined ? _switchEffect : null,
                        child: Text('${playEffect ? 'Stop' : 'Play'} effect'),
                      ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        const Text('RecordingVolume:'),
                        Slider(
                          value: _recordingVolume,
                          min: 0,
                          max: 400,
                          divisions: 5,
                          label: 'RecordingVolume',
                          onChanged: isJoined
                              ? (double value) async {
                                  setState(() {
                                    _recordingVolume = value;
                                  });
                                  await _engine.adjustRecordingSignalVolume(value.toInt());
                                }
                              : null,
                        )
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        const Text('PlaybackVolume:'),
                        Slider(
                          value: _playbackVolume,
                          min: 0,
                          max: 400,
                          divisions: 5,
                          label: 'PlaybackVolume',
                          onChanged: isJoined
                              ? (double value) async {
                                  setState(() {
                                    _playbackVolume = value;
                                  });
                                  await _engine.adjustPlaybackSignalVolume(value.toInt());
                                }
                              : null,
                        )
                      ],
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Row(mainAxisSize: MainAxisSize.min, children: [
                          const Text('InEar Monitoring Volume:'),
                          Switch(
                            value: _enableInEarMonitoring,
                            onChanged: isJoined ? _toggleInEarMonitoring : null,
                            activeTrackColor: Colors.grey[350],
                            activeColor: Colors.white,
                          )
                        ]),
                        if (_enableInEarMonitoring)
                          SizedBox(
                              width: 300,
                              child: Slider(
                                value: _inEarMonitoringVolume,
                                min: 0,
                                max: 100,
                                divisions: 5,
                                label: 'InEar Monitoring Volume $_inEarMonitoringVolume',
                                onChanged: isJoined ? _onChangeInEarMonitoringVolume : null,
                              ))
                      ],
                    ),
                  ],
                ),
              ))
        ],
      ),
    );
  }
}
