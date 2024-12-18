import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';
import 'package:flutter_sms/flutter_sms.dart';
import 'package:contacts_service/contacts_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:volume_control/volume_control.dart'; // volume_control 패키지 추가

// 앱의 진입점 (main 함수)
void main() => runApp(AlarmApp());

// AlarmApp 클래스: 앱의 최상위 위젯
class AlarmApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false, // 디버그 배너 숨기기
      title: 'Alarm App', // 앱 제목
      theme: ThemeData(primarySwatch: Colors.blue), // 테마 설정
      home: AlarmHomePage(), // 기본 화면 설정
    );
  }
}

// 알람 정보를 저장하는 데이터 클래스
class Alarm {
  TimeOfDay time; // 알람 시간
  DateTime dateTime; // 알람 날짜와 시간
  int interval; // 반복 간격(분)
  Timer? timer; // 알람 타이머
  int count; // 현재 알람 발생 횟수

  // 생성자
  Alarm({
    required this.time,
    required this.dateTime,
    required this.interval,
    this.timer,
    this.count = 0,
  });
}

// AlarmHomePage 클래스: 알람 관리 화면
class AlarmHomePage extends StatefulWidget {
  @override
  _AlarmHomePageState createState() => _AlarmHomePageState();
}

class _AlarmHomePageState extends State<AlarmHomePage> {
  List<Alarm> alarms = []; // 등록된 알람 리스트
  final AudioPlayer _audioPlayer = AudioPlayer(); // 오디오 플레이어

  // 알람 추가 함수
  void setAlarm(TimeOfDay time, DateTime dateTime, int interval) {
    final now = DateTime.now(); // 현재 시간
    final alarmDateTime = DateTime(dateTime.year, dateTime.month, dateTime.day, time.hour, time.minute);

    // 알람 시간이 현재 시간 이전이면 설정하지 않음
    if (alarmDateTime.isBefore(now)) {
      Fluttertoast.showToast(
        msg: "현재시간 이후로 설정하여야 합니다.",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
      );
      return;
    }

    Duration initialDelay = alarmDateTime.difference(now); // 알람까지의 초기 지연 시간

    // 새로운 알람 객체 생성
    Alarm newAlarm = Alarm(time: time, dateTime: alarmDateTime, interval: interval);

    // 반복 타이머 설정
    newAlarm.timer = Timer.periodic(Duration(minutes: interval), (timer) {
      if (newAlarm.count >= 3) {
        sendRandomMessage(); // 3회 반복 후 랜덤 메시지 전송
        timer.cancel();
      } else {
        showAlarmScreen(); // 알람 화면 표시
        newAlarm.count++;
      }
    });

    // 초기 알람 실행 예약
    Future.delayed(initialDelay, () {
      showAlarmScreen();
      newAlarm.count++;
    });

    setState(() {
      alarms.add(newAlarm); // 알람 리스트에 추가
    });
  }

  // 알람 삭제 함수
  void deleteAlarm(int index) {
    setState(() {
      alarms[index].timer?.cancel(); // 타이머 취소
      alarms.removeAt(index); // 리스트에서 삭제
    });
  }

  // 랜덤 연락처로 메시지 전송 함수
  Future<void> sendRandomMessage() async {
    // 연락처 접근 권한 확인 및 요청
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

    // 연락처 불러오기
    Iterable<Contact> contacts = await ContactsService.getContacts();
    if (contacts.isEmpty) {
      Fluttertoast.showToast(
        msg: "저장된 연락처가 없습니다.",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
      );
      return;
    }

    // 랜덤 연락처 선택
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

    // 전화 및 문자 메시지 전송
    final uri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri); // 전화 걸기
      Fluttertoast.showToast(
        msg: "전화 걸기: $phoneNumber",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
      );

      // 문자 메시지 전송
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

  // 알람 화면 표시
  void showAlarmScreen() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => AlarmScreen(
          onDismiss: () {}, // 알람 종료 콜백
          playSound: playSoundIgnoringSilentMode, // 무음 모드에서도 소리 재생
        ),
      ),
    );
  }

  // 알람 소리 재생 함수
  Future<void> playSoundIgnoringSilentMode() async {
    await _audioPlayer.play(
      AssetSource('assets/audio/alarm_sound.mp3'),
      volume: 1.0,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Alarm App')), // 화면 제목
      body: ListView.builder(
        itemCount: alarms.length, // 알람 개수
        itemBuilder: (context, index) {
          final alarm = alarms[index];
          return ListTile(
            title: Text(
              '${alarm.dateTime.year}-${alarm.dateTime.month}-${alarm.dateTime.day} '
                  '${alarm.time.format(context)} - Every ${alarm.interval} minutes',
            ),
            trailing: IconButton(
              icon: Icon(Icons.delete),
              onPressed: () => deleteAlarm(index), // 삭제 버튼
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          // 알람 설정 화면으로 이동
          final result = await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => TimeSelectionScreen(),
            ),
          );
          if (result != null && result is Map<String, dynamic>) {
            setAlarm(result['time'], result['dateTime'], result['interval']); // 알람 추가
          }
        },
        child: Icon(Icons.add), // 추가 버튼
      ),
    );
  }
}

// 알람이 울릴 때 표시되는 화면
class AlarmScreen extends StatefulWidget {
  final VoidCallback onDismiss; // 알람 종료 콜백 함수
  final Future<void> Function() playSound; // 소리 재생 함수

  AlarmScreen({required this.onDismiss, required this.playSound});

  @override
  _AlarmScreenState createState() => _AlarmScreenState();
}

class _AlarmScreenState extends State<AlarmScreen> {
  Timer? _closeTimer; // 일정 시간 후 자동 종료 타이머

  @override
  void initState() {
    super.initState();

    widget.playSound(); // 화면이 나타나면 소리 재생

    // 30초 후 알람 자동 종료
    _closeTimer = Timer(Duration(seconds: 30), () {
      if (mounted) {
        widget.onDismiss();
        Navigator.of(context).pop(); // 화면 종료
      }
    });
  }

  @override
  void dispose() {
    _closeTimer?.cancel(); // 타이머 해제
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.red, // 배경 색상
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 현재 시간 표시
            Text(
              TimeOfDay.now().format(context),
              style: TextStyle(fontSize: 48, color: Colors.white),
            ),
            // 알람 종료 버튼
            ElevatedButton(
              onPressed: () {
                widget.onDismiss();
                Navigator.of(context).pop(); // 화면 종료
              },
              child: Text('X'),
            ),
          ],
        ),
      ),
    );
  }
}

// 알람 시간, 날짜, 간격 설정 화면
class TimeSelectionScreen extends StatefulWidget {
  @override
  _TimeSelectionScreenState createState() => _TimeSelectionScreenState();
}

class _TimeSelectionScreenState extends State<TimeSelectionScreen> {
  TimeOfDay? selectedTime; // 선택된 시간
  DateTime? selectedDate; // 선택된 날짜
  int intervalMinutes = 1; // 반복 간격(분)
  double volume = 1.0; // 현재 볼륨 상태

  @override
  void initState() {
    super.initState();
    _initVolume(); // 초기 볼륨 값 설정
  }

  // 시스템 볼륨 초기화 함수
  Future<void> _initVolume() async {
    volume = await VolumeControl.volume; // 현재 시스템 볼륨 값 가져오기
    setState(() {});
  }

  // 시스템 볼륨 설정 함수
  Future<void> _setVolume(double newVolume) async {
    await VolumeControl.setVolume(newVolume); // 새로 설정된 볼륨으로 변경
    setState(() {
      volume = newVolume; // 현재 볼륨 상태 업데이트
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('시간 설정하기'), // 화면 제목
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 시간 설정 버튼
            TextButton(
              onPressed: () async {
                final time = await showTimePicker(
                  context: context,
                  initialTime: TimeOfDay.now(), // 현재 시간 기본값
                );
                if (time != null) {
                  setState(() {
                    selectedTime = time; // 선택된 시간 저장
                  });
                }
              },
              child: Text(selectedTime == null
                  ? '시간 설정하기'
                  : '시간 설정하기: ${selectedTime!.format(context)}'),
            ),
            SizedBox(height: 32),
            // 날짜 설정 버튼
            TextButton(
              onPressed: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now(), // 오늘 날짜 기본값
                  firstDate: DateTime.now(), // 오늘 이전 선택 불가
                  lastDate: DateTime(2100), // 최대 선택 가능 날짜
                );
                if (date != null) {
                  setState(() {
                    selectedDate = date; // 선택된 날짜 저장
                  });
                }
              },
              child: Text(selectedDate == null
                  ? '날짜 설정하기'
                  : '날짜 설정하기: ${selectedDate!.year}-${selectedDate!.month}-${selectedDate!.day}'),
            ),
            SizedBox(height: 32),
            // 반복 간격 설정
            Text('시간 간격 설정하기:'),
            DropdownButton<int>(
              value: intervalMinutes, // 현재 선택된 간격
              items: [
                for (int i = 1; i <= 60; i++)
                  DropdownMenuItem(value: i, child: Text('$i 분')), // 1~60분 옵션
              ],
              onChanged: (value) {
                setState(() {
                  intervalMinutes = value!; // 선택된 간격 저장
                });
              },
            ),
            SizedBox(height: 32),
            // 볼륨 설정 슬라이더
            Text('시스템 볼륨 설정하기:'),
            Slider(
              value: volume, // 현재 볼륨 상태
              min: 0.0,
              max: 1.0,
              onChanged: (newVolume) {
                _setVolume(newVolume); // 볼륨 변경
              },
            ),
            SizedBox(height: 32),
            // 저장 버튼
            ElevatedButton(
              onPressed: () {
                if (selectedTime != null && selectedDate != null) {
                  // 설정된 시간, 날짜, 간격 반환
                  Navigator.of(context).pop({
                    'time': selectedTime,
                    'dateTime': selectedDate,
                    'interval': intervalMinutes,
                  });
                } else {
                  // 설정이 완료되지 않은 경우 경고 메시지
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
