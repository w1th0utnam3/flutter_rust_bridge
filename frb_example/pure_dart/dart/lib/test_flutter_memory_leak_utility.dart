import 'dart:async';
import 'dart:developer';
import 'dart:io';
import 'dart:isolate';

import 'package:vm_service/vm_service.dart' hide Isolate, Log;
import 'package:vm_service/vm_service.dart' as vm_service;
import 'package:vm_service/vm_service_io.dart';

/// https://stackoverflow.com/questions/63730179/can-we-force-the-dart-garbage-collector
class VmServiceUtil {
  final VmService vmService;

  VmServiceUtil._(this.vmService);

  static Future<VmServiceUtil> create() async {
    final serverUri = (await Service.getInfo()).serverUri;
    if (serverUri == null) {
      throw Exception('Cannot find serverUri for VmService. '
          'Ensure you run like `dart run --enable-vm-service path/to/your/file.dart`');
    }

    final vmService = await vmServiceConnectUri(_toWebSocket(serverUri), log: _Log());
    return VmServiceUtil._(vmService);
  }

  void dispose() {
    vmService.dispose();
  }

  Future<void> gc() async {
    final isolateId = Service.getIsolateID(Isolate.current)!;
    final profile = await vmService.getAllocationProfile(isolateId, gc: true);
    log('gc triggered (heapUsage=${profile.memoryUsage?.heapUsage})');
  }
}

String _toWebSocket(Uri uri) {
  final pathSegments = [...uri.pathSegments.where((s) => s.isNotEmpty), 'ws'];
  return uri.replace(scheme: 'ws', pathSegments: pathSegments).toString();
}

class _Log extends vm_service.Log {
  @override
  void warning(String message) => log('Warning: $message');

  @override
  void severe(String message) => log('Severe: $message');
}

Future<void> executeProcess(String executable, List<String> arguments) async {
  log('executeProcess start `$executable ${arguments.join(" ")}`');

  final process = await Process.start(executable, arguments);

  process.stdout.listen((e) => log(String.fromCharCodes(e)));
  process.stderr.listen((e) => log('[STDERR] ${String.fromCharCodes(e)}'));

  final exitCode = await process.exitCode;
  log('executeProcess end exitCode=$exitCode');
  if (exitCode != 0) {
    throw Exception('Process execution failed (exitCode=$exitCode)');
  }
}
