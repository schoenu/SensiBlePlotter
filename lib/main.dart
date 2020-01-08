// Copyright 2020, schoenu

import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_blue/flutter_blue.dart';
import 'package:sensi_ble_plotter/widgets.dart';
import 'dart:convert' show utf8;

void main() {
  runApp(FlutterBlueApp());
}

class FlutterBlueApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      color: Colors.lightBlue,
      home: StreamBuilder<BluetoothState>(
          stream: FlutterBlue.instance.state,
          initialData: BluetoothState.unknown,
          builder: (c, snapshot) {
            final state = snapshot.data;
            if (state == BluetoothState.on) {
              return FindDevicesScreen();
            }
            return BluetoothOffScreen(state: state);
          }),
    );
  }
}

class BluetoothOffScreen extends StatelessWidget {
  const BluetoothOffScreen({Key key, this.state}) : super(key: key);

  final BluetoothState state;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.lightBlue,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.bluetooth_disabled,
              size: 200.0,
              color: Colors.white54,
            ),
            Text(
              'Bluetooth Adapter is ${state.toString().substring(15)}.',
              style: Theme.of(context)
                  .primaryTextTheme
                  .subhead
                  .copyWith(color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}

class FindDevicesScreen extends StatelessWidget {//
  //List<Guid> service_filter = [new Guid('ebe0ccb0-7a0a-4b0c-8a1a-6ff2997da3a6')];
  List<Guid> service_filter = [new Guid('00008000-b38d-4985-720e-0f993a68ee41'),
    new Guid('00005588-b38d-4985-720e-0f993a68ee41'),
    new Guid('0000181a-0000-1000-8000-00805f9b34fb')];

  // Listen to scan results
  // ignore: cancel_subscriptions
//  var filter_scan_results = FlutterBlue.instance.scanResults.listen(ondata)  {
//    debugPrint('got scan result');
//  });
//
//  _discoverServicesAndSetTime() async {
//    List<BluetoothService> services = await FlutterBlue.instance.scanResults.listen(onData);
//    services.forEach((service) async {
//
////  Future<int> filter_scan_results(Stream<int> stream) async {
////    var sum = 0;
////    await for (var value in FlutterBlue.instance.scanResults) {
////      debugPrint('recieced result');
////    }
////    return sum;
//  }
//  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Find Devices'),
        backgroundColor: Colors.lightGreen,
      ),
      body: RefreshIndicator(
        onRefresh: () =>
            FlutterBlue.instance.startScan(timeout: Duration(seconds: 4)),
        child: SingleChildScrollView(
          child: Column(
            children: <Widget>[
              StreamBuilder<List<BluetoothDevice>>(
                stream: Stream.periodic(Duration(seconds: 2))
                    .asyncMap((_) => FlutterBlue.instance.connectedDevices),
                initialData: [],
                builder: (c, snapshot) => Column(
                  children: snapshot.data
                      .map((d) => ListTile(
                            title: Text(d.name),
                            subtitle: Text(d.id.toString()),
                            trailing: StreamBuilder<BluetoothDeviceState>(
                              stream: d.state,
                              initialData: BluetoothDeviceState.disconnected,
                              builder: (c, snapshot) {
                                if (snapshot.data ==
                                    BluetoothDeviceState.connected) {
                                  return RaisedButton(
                                    child: Text('OPEN'),
                                    onPressed: () => Navigator.of(context).push(
                                        MaterialPageRoute(
                                            builder: (context) =>
                                                DeviceScreen(device: d))),
                                  );
                                }
                                return Text(snapshot.data.toString());
                              },
                            ),
                          ))
                      .toList(),
                ),
              ),
              StreamBuilder<List<ScanResult>>(
                stream: FlutterBlue.instance.scanResults,
                initialData: [],
                builder: (c, snapshot) => Column(
                  children: snapshot.data
                      .map(
                        (r) => ScanResultTile(
                          result: r,
                          onTap: () => Navigator.of(context)
                              .push(MaterialPageRoute(builder: (context) {
                            r.device.connect(timeout: Duration(seconds: 4));
                            return DeviceScreen(device: r.device);
                          })),
                        ),
                      )
                      .toList(),
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: StreamBuilder<bool>(
        stream: FlutterBlue.instance.isScanning,
        initialData: false,
        builder: (c, snapshot) {
          if (snapshot.data) {
            return FloatingActionButton(
              child: Icon(Icons.stop),
              onPressed: () => FlutterBlue.instance.stopScan(),
              backgroundColor: Colors.red,
            );
          } else {
            return FloatingActionButton(
                child: Icon(Icons.search),
                backgroundColor: Colors.green,
                onPressed: () => FlutterBlue.instance
                    .startScan(timeout: Duration(seconds: 4),
//                    withServices: service_filter
                    ));
          }
        },
      ),
    );
  }
}

class PlotTile{
  String descriptorString;

  PlotTile(descriptorString){
    debugPrint('created PlotTile '+descriptorString);
    this.descriptorString = descriptorString;
  }

  void onData(List<int> rawValue) {
    if (rawValue.length == 4) {
      ByteBuffer buffer = new Int8List.fromList(rawValue).buffer;
      ByteData byteData = new ByteData.view(buffer);
      double doubleValue = byteData.getFloat32(0, Endian.little);
      debugPrint(this.descriptorString+': '+doubleValue.toString());
    }
    else if (rawValue.length == 2) {
      debugPrint(rawValue.toString());
      ByteBuffer buffer = new Int8List.fromList(rawValue).buffer;
      ByteData byteData = new ByteData.view(buffer);
      int intValue = byteData.getUint16(0, Endian.little);
      debugPrint(this.descriptorString+': '+intValue.toString());
    }
    else {
      debugPrint('Unknown value type for '+this.descriptorString);
    }
  }
}

class DeviceScreen extends StatelessWidget {
  const DeviceScreen({Key key, this.device}) : super(key: key);

  final BluetoothDevice device;
  //final GlobalKey<ScaffoldState> mScaffoldState = new GlobalKey<ScaffoldState>();

  List<int> _getRandomBytes() {
    final math = Random();
    return [
      math.nextInt(255),
      math.nextInt(255),
      math.nextInt(255),
      math.nextInt(255)
    ];
  }

  _subscribeToServices() async {
    List<Guid> acceptedGUID = [
      //RH
      new Guid('00001234-b38d-4985-720e-0f993a68ee41'),
      new Guid('00001235-b38d-4985-720e-0f993a68ee41'),
      //T
      new Guid('00002234-b38d-4985-720e-0f993a68ee41'),
      new Guid('00002235-b38d-4985-720e-0f993a68ee41'),
    ];

    List<BluetoothService> services = await device.discoverServices();
    services.forEach((service) async {
      //debugPrint(service.uuid.toString());
      if (acceptedGUID.contains(service.uuid)) {
        debugPrint('Accepted service was found');
        for (BluetoothCharacteristic char in service.characteristics){
          if (acceptedGUID.contains(service.uuid)) {

            var descriptors = char.descriptors;
            for(BluetoothDescriptor d in descriptors) {
              List<int> descriptorIntList = await d.read();
              if (descriptorIntList.length > 0) {
                List<int> descriptorIntList = await descriptors.last.read();
                String descriptorString = new String.fromCharCodes(descriptorIntList);
//                descriptorString = utf8.encode(input)
                debugPrint(descriptorString);
                PlotTile pt = new PlotTile(descriptorString);
                await char.setNotifyValue(true);
                char.value.listen(pt.onData);
              }
            }
          }
        }
      }
    });
  }

  _discoverServicesAndSetTime() async {
    List<BluetoothService> services = await device.discoverServices();
    services.forEach((service) async {
      //debugPrint(service.uuid.toString());
      if (service.uuid == new Guid('ebe0ccb0-7a0a-4b0c-8a1a-6ff2997da3a6')) {
        debugPrint('Time Service found');
        for (BluetoothCharacteristic char in service.characteristics){
          if (char.uuid == new Guid('EBE0CCB7-7A0A-4B0C-8A1A-6FF2997DA3A6')) {
            debugPrint('Time Char found');
            DateTime now = new DateTime.now();
            int nowEpoch = now.millisecondsSinceEpoch;
            int timeZoneOffset = now.timeZoneOffset.inHours;
            nowEpoch =  (nowEpoch~/1000);
            //List<int> value = await char.read();

            //prepare send list
            var buffer = new Uint8List(5).buffer;
            var bdata = new ByteData.view(buffer);
            bdata.setInt32(0, nowEpoch, Endian.little);
            List<int> toSend = new Uint8List.view(buffer);
            toSend.last = timeZoneOffset;

            debugPrint(nowEpoch.toString());
            debugPrint(timeZoneOffset.toString());
            debugPrint(toSend.toString());

            await char.write(toSend);
            debugPrint('New time written');
          }
        }
      }
    });
  }

  _displaySnackbar(String message, BuildContext context){
    debugPrint(message);

    final snackBar = SnackBar(content: Text(message));
    Scaffold.of(context).showSnackBar(snackBar);

    //final snackBar = SnackBar(content: Text('Yay! A SnackBar!'));
    //Scaffold.of(context).showSnackBar(snackBar);
  }


  List<Widget> _buildServiceTiles(List<BluetoothService> services) {
    return services
        .map(
          (s) => ServiceTile(
            service: s,
            characteristicTiles: s.characteristics
                .map(
                  (c) => CharacteristicTile(
                    characteristic: c,
                    onReadPressed: () => c.read(),
                    onWritePressed: () => c.write(_getRandomBytes()),
                    onNotificationPressed: () =>
                        c.setNotifyValue(!c.isNotifying),
                    descriptorTiles: c.descriptors
                        .map(
                          (d) => DescriptorTile(
                            descriptor: d,
                            onReadPressed: () => d.read(),
                            onWritePressed: () => d.write(_getRandomBytes()),
                          ),
                        )
                        .toList(),
                  ),
                )
                .toList(),
          ),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(device.name),
        actions: <Widget>[
          StreamBuilder<BluetoothDeviceState>(
            stream: device.state,
            initialData: BluetoothDeviceState.connecting,
            builder: (c, snapshot) {
              VoidCallback onPressed;
              String text;
              switch (snapshot.data) {
                case BluetoothDeviceState.connected:
                  onPressed = () => device.disconnect();
                  text = 'DISCONNECT';
                  break;
                case BluetoothDeviceState.disconnected:
                  onPressed = () => device.connect(timeout: Duration(seconds: 4));
                  text = 'CONNECT';
                  break;
                default:
                  onPressed = null;
                  text = snapshot.data.toString().substring(21).toUpperCase();
                  break;
              }
              return FlatButton(
                  onPressed: onPressed,
                  child: Text(
                    text,
                    style: Theme.of(context)
                        .primaryTextTheme
                        .button
                        .copyWith(color: Colors.white),
                  ));
            },
          )
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: <Widget>[
            StreamBuilder<BluetoothDeviceState>(
              stream: device.state,
              initialData: BluetoothDeviceState.connecting,
              builder: (c, snapshot) => ListTile(
                leading: (snapshot.data == BluetoothDeviceState.connected)
                    ? Icon(Icons.bluetooth_connected)
                    : Icon(Icons.bluetooth_disabled),
                title: Text(
                    'Device is ${snapshot.data.toString().split('.')[1]}.'),
                subtitle: Text('${device.id}'),
                //trailing: Text('Hello Me'),
                trailing: StreamBuilder<bool>(
                  stream: device.isDiscoveringServices,
                  initialData: false,
                    /*builder: (c, snapshot) => IconButton(
                      icon: Icon(Icons.add_alarm),
                      onPressed: () => _discoverServicesAndSetTime(),
                    )*/
                    builder: (context, snapshot) => SizedBox(
                      width: 100.0,
                      child: Row(
                        //mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            icon: Icon(Icons.add_alarm),
                            onPressed: () => _subscribeToServices(),
                            ),
                          IconButton(
                            icon: Icon(Icons.search),
                            onPressed: () => _displaySnackbar('Search services', c),
                          ),
                        ],
                      ),
                    ),

                  /*builder: (c, snapshot) => IndexedStack(
                    index: snapshot.data ? 1 : 0,
                    children: <Widget>[
                      IconButton(
                        icon: Icon(Icons.add_alarm),
                        onPressed: () => _discoverServicesAndSetTime(),
                      ),
                      IconButton(
                        icon: SizedBox(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation(Colors.grey),
                          ),
                          width: 18.0,
                          height: 18.0,
                        ),
                        onPressed: null,
                      )
                    ],
                  ), */
                ),
              ),
            ),
            /*StreamBuilder<int>(
              stream: device.mtu,
              initialData: 0,
              builder: (c, snapshot) => ListTile(
                title: Text('MTU Size'),
                subtitle: Text('${snapshot.data} bytes'),
                trailing: IconButton(
                  icon: Icon(Icons.edit),
                  onPressed: () => device.requestMtu(223),
                ),
              ),
            ),*/
            StreamBuilder<List<BluetoothService>>(
              stream: device.services,
              initialData: [],
              builder: (c, snapshot) {
                return Column(
                  children: _buildServiceTiles(snapshot.data),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
