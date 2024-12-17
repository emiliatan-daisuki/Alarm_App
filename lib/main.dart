import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';
import 'package:flutter_sms/flutter_sms.dart';
import 'package:contacts_service/contacts_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:audioplayers/audioplayers.dart';

void main() => runApp(AlarmApp());

class AlarmApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Alarm App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: AlarmHomePage(),
    );
  }
}

class Alarm {
  TimeOfDay time;
  DateTime dateTime;
  int interval;
  Timer? timer;
  int count;

  Alarm({
    required this.time,
    required this.dateTime,
    required this.interval,
    this.timer,
    this.count = 0,
  });
}

class AlarmHomePage extends StatefulWidget {
  @override
  _AlarmHomePageState createState() => _AlarmHomePageState();
}

class _AlarmHomePageState extends State<AlarmHomePage> {
  List<Alarm> alarms = [];
  final AudioPlayer _audioPlayer = AudioPlayer();

  void setAlarm(TimeOfDay time, DateTime dateTime, int interval) {
    final now = DateTime.now();
    final alarmDateTime = DateTime(dateTime.year, dateTime.month, dateTime.day, time.hour, time.minute);

    if (alarmDateTime.isBefore(now)) {
        Fluttertoast.showToast(
          msg: "현재시간 이후로 설정하여야 합니다.",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
        );
        return;
    }

    Duration initialDelay = alarmDateTime.difference(now);

    Alarm newAlarm = Alarm(time: time, dateTime: alarmDateTime, interval: interval);

    newAlarm.timer = Timer.periodic(Duration(minutes: interval), (timer) {
      if (newAlarm.count >= 3) {
        sendRandomMessage();
        timer.cancel();
      } else {
        showAlarmScreen();
        newAlarm.count++;
      }
    });

    Future.delayed(initialDelay, () {
      showAlarmScreen();
      newAlarm.count++;
    });

    setState(() {
      alarms.add(newAlarm);
    });
  }

  void deleteAlarm(int index) {
    setState(() {
      alarms[index].timer?.cancel();
      alarms.removeAt(index);
    });
  }

  Future<void> sendRandomMessage() async {
    PermissionStatus permissionStatus = await Permission.contacts.status;
    if (permissionStatus != PermissionStatus.granted) {
      permissionStatus = await Permission.contacts.request();
      if (permissionStatus != PermissionStatus.granted) {
        Fluttertoast.showToast(
          msg: "연락처 접근 권한이 거부되었습니다.",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
        );
        return;
      }
    }

    Iterable<Contact> contacts = await ContactsService.getContacts();
    if (contacts.isEmpty) {
      Fluttertoast.showToast(
        msg: "저장된 연락처가 없습니다.",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
      );
      return;
    }

    final random = Random();
    final randomContact = contacts.elementAt(random.nextInt(contacts.length));
    final phoneNumber = randomContact.phones?.isNotEmpty == true
        ? randomContact.phones!.first.value
        : null;

    if (phoneNumber == null) {
      Fluttertoast.showToast(
        msg: "선택된 연락처에 전화번호가 없습니다.",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
      );
      return;
    }

    final uri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
      Fluttertoast.showToast(
        msg: "전화 걸기: $phoneNumber",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
      );

      String message = "개발 중인 앱 테스트 중";
      await sendSMS(message: message, recipients: [phoneNumber]).catchError((error) {
        print('문자 전송 실패: $error');
      });
    } else {
      Fluttertoast.showToast(
        msg: "전화 걸기 실패",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
      );
    }
  }

  void showAlarmScreen() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => AlarmScreen(
          onDismiss: () {},
          playSound: playSoundIgnoringSilentMode,
        ),
      ),
    );
  }

  Future<void> playSoundIgnoringSilentMode() async {
    await _audioPlayer.play(
      AssetSource('assets/audio/alarm_sound.mp3'),
      volume: 1.0,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Alarm App'),
      ),
      body: ListView.builder(
        itemCount: alarms.length,
        itemBuilder: (context, index) {
          final alarm = alarms[index];
          return ListTile(
            title: Text(
              '${alarm.dateTime.year}-${alarm.dateTime.month}-${alarm.dateTime.day} '
                  '${alarm.time.format(context)} - Every ${alarm.interval} minutes',
            ),
            trailing: IconButton(
              icon: Icon(Icons.delete),
              onPressed: () => deleteAlarm(index),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => TimeSelectionScreen(),
            ),
          );
          if (result != null && result is Map<String, dynamic>) {
            setAlarm(result['time'], result['dateTime'], result['interval']);
          }
        },
        child: Icon(Icons.add),
      ),
    );
  }
}

class AlarmScreen extends StatefulWidget {
  final VoidCallback onDismiss;
  final Future<void> Function() playSound;

  AlarmScreen({required this.onDismiss, required this.playSound});

  @override
  _AlarmScreenState createState() => _AlarmScreenState();
}

class _AlarmScreenState extends State<AlarmScreen> {
  Timer? _closeTimer;

  @override
  void initState() {
    super.initState();

    widget.playSound();

    _closeTimer = Timer(Duration(seconds: 30), () {
      if (mounted) {
        widget.onDismiss();
        Navigator.of(context).pop();
      }
    });
  }

  @override
  void dispose() {
    _closeTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.red,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              TimeOfDay.now().format(context),
              style: TextStyle(fontSize: 48, color: Colors.white),
            ),
            ElevatedButton(
              onPressed: () {
                widget.onDismiss();
                Navigator.of(context).pop();
              },
              child: Text('X'),
            ),
          ],
        ),
      ),
    );
  }
}

class TimeSelectionScreen extends StatefulWidget {
  @override
  _TimeSelectionScreenState createState() => _TimeSelectionScreenState();
}

class _TimeSelectionScreenState extends State<TimeSelectionScreen> {
  TimeOfDay? selectedTime;
  DateTime? selectedDate;
  int intervalMinutes = 1;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('시간 설정하기'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextButton(
              onPressed: () async {
                final time = await showTimePicker(
                  context: context,
                  initialTime: TimeOfDay.now(),
                );
                if (time != null) {
                  setState(() {
                    selectedTime = time;
                  });
                }
              },
              child: Text(selectedTime == null
                  ? '시간 설정하기'
                  : '시간 설정하기: ${selectedTime!.format(context)}'),
            ),
            SizedBox(height: 32),
            TextButton(
              onPressed: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now(),
                  firstDate: DateTime.now(),
                  lastDate: DateTime(2100),
                );
                if (date != null) {
                  setState(() {
                    selectedDate = date;
                  });
                }
              },
              child: Text(selectedDate == null
                  ? '날짜 설정하기'
                  : '날짜 설정하기: ${selectedDate!.year}-${selectedDate!.month}-${selectedDate!.day}'),
            ),
            SizedBox(height: 32),
            Text('시간 간격 설정하기:'),
            DropdownButton<int>(
              value: intervalMinutes,
              items: [
                for (int i = 1; i <= 60; i++)
                  DropdownMenuItem(value: i, child: Text('$i 분')),
              ],
              onChanged: (value) {
                setState(() {
                  intervalMinutes = value!;
                });
              },
            ),
            SizedBox(height: 32),
            ElevatedButton(
              onPressed: () {
                if (selectedTime != null && selectedDate != null) {
                  Navigator.of(context).pop({
                    'time': selectedTime,
                    'dateTime': selectedDate,
                    'interval': intervalMinutes,
                  });
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('시간과 날짜를 선택해주세요.')),
                  );
                }
              },
              child: Text('저장하기'),
            ),
          ],
        ),
      ),
    );
  }
}
