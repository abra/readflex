import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

String repositoryRootFromScript([Uri? script]) =>
    p.normalize(p.fromUri((script ?? Platform.script).resolve('../')));

/// Splits command prefixes such as `fvm dart`, without invoking a shell.
List<String> splitCommand(String value, {bool? windows}) {
  final windowsMode = windows ?? Platform.isWindows;
  final words = <String>[];
  var word = StringBuffer();
  String? quote;
  var started = false;
  for (var index = 0; index < value.length; index++) {
    final character = value[index];
    if (character == r'\' && quote != "'") {
      if (windowsMode) {
        if (quote == '"' &&
            index + 1 < value.length &&
            value[index + 1] == '"') {
          word.write('"');
          index++;
        } else {
          word.write(character);
        }
        started = true;
        continue;
      }
      if (++index == value.length) {
        throw const FormatException('Trailing command escape');
      }
      word.write(value[index]);
      started = true;
    } else if (quote != null) {
      if (character == quote) {
        quote = null;
      } else {
        word.write(character);
      }
      started = true;
    } else if (character == '"' || character == "'") {
      quote = character;
      started = true;
    } else if (character.trim().isEmpty) {
      if (started) {
        words.add(word.toString());
        word = StringBuffer();
        started = false;
      }
    } else {
      word.write(character);
      started = true;
    }
  }
  if (quote != null) throw const FormatException('Unclosed command quote');
  if (started) words.add(word.toString());
  if (words.isEmpty || words.first.isEmpty) {
    throw const FormatException('Empty command');
  }
  return words;
}

/// Resolves FVM before a subprocess moves outside the repository.
List<String> dartCommand({Map<String, String>? environment, String? root}) {
  final variables = environment ?? Platform.environment;
  final project = root ?? Directory.current.path;
  final executable = Platform.isWindows ? 'dart.exe' : 'dart';
  final pinned = File(
    p.join(
      project,
      '.fvm',
      'flutter_sdk',
      'bin',
      'cache',
      'dart-sdk',
      'bin',
      executable,
    ),
  );
  final configured = variables['DART'];
  if (configured != null && configured.trim().isNotEmpty) {
    final command = splitCommand(configured);
    if (p.basenameWithoutExtension(command.first) == 'fvm' &&
        command.length >= 2 &&
        command[1] == 'dart') {
      if (!pinned.existsSync()) {
        throw StateError('Pinned Dart SDK missing in $project; run fvm use');
      }
      return [pinned.resolveSymbolicLinksSync(), ...command.skip(2)];
    }
    return command;
  }
  if (pinned.existsSync()) return [pinned.resolveSymbolicLinksSync()];
  if (p.basenameWithoutExtension(Platform.resolvedExecutable) == 'dart') {
    return [Platform.resolvedExecutable];
  }
  throw StateError(
    'Cannot locate Dart SDK; set DART or run fvm use in $project',
  );
}

Future<ProcessResult> runCommand(
  List<String> command, {
  String? workingDirectory,
  Map<String, String>? environment,
  Duration? timeout,
  int? maxOutputBytes,
  bool inheritStdio = false,
}) async {
  if (command.isEmpty || command.first.isEmpty) {
    throw ArgumentError.value(command, 'command', 'Missing executable');
  }
  final limit = maxOutputBytes ?? 64 * 1024 * 1024;
  if (limit <= 0) throw ArgumentError.value(limit, 'maxOutputBytes');
  final process = await Process.start(
    command.first,
    command.skip(1).toList(),
    workingDirectory: workingDirectory,
    environment: environment,
    mode: inheritStdio
        ? ProcessStartMode.inheritStdio
        : ProcessStartMode.normal,
  );
  final captures = inheritStdio
      ? <_CommandOutput>[]
      : [
          _CommandOutput(process.stdout, limit, command.first),
          _CommandOutput(process.stderr, limit, command.first),
        ];
  final output = inheritStdio
      ? Future.value(<String>['', ''])
      : Future.wait(
          captures.map((capture) => capture.result),
          eagerError: true,
        );
  // Attach the output error handler before waiting for the exit code.
  final result = Future.wait<Object>(
    [
      process.exitCode,
      output,
      if (!inheritStdio) process.stdin.close().then<Object>((_) => 0),
    ],
    eagerError: true,
  );
  try {
    final values = timeout == null
        ? await result
        : await result.timeout(timeout);
    final status = values[0] as int;
    final streams = values[1] as List<String>;
    if (status != 0) {
      throw ProcessException(
        command.first,
        command.skip(1).toList(),
        streams[1].isEmpty ? streams[0] : streams[1],
        status,
      );
    }
    return ProcessResult(process.pid, status, streams[0], streams[1]);
  } catch (_) {
    process.kill();
    // Close pipes even when a child ignores SIGTERM or a descendant retains them.
    try {
      await Future.wait(captures.map((capture) => capture.cancel()));
    } catch (_) {
      // Preserve the command error if closing an output stream also fails.
    }
    try {
      await process.exitCode.timeout(const Duration(seconds: 2));
    } on TimeoutException {
      process.kill(ProcessSignal.sigkill);
      await process.exitCode;
    }
    rethrow;
  }
}

class _CommandOutput {
  _CommandOutput(Stream<List<int>> stream, int limit, String program) {
    _subscription = stream.listen(
      (chunk) {
        if (_completion.isCompleted) return;
        if (_bytes.length + chunk.length > limit) {
          _completion.completeError(
            StateError('Command output exceeds $limit bytes: $program'),
          );
          _subscription.pause();
        } else {
          _bytes.add(chunk);
        }
      },
      onError: (Object error, StackTrace stack) {
        if (!_completion.isCompleted) _completion.completeError(error, stack);
      },
      onDone: () {
        if (!_completion.isCompleted) {
          _completion.complete(
            utf8.decode(_bytes.takeBytes(), allowMalformed: true),
          );
        }
      },
      cancelOnError: true,
    );
  }

  final _completion = Completer<String>();
  final _bytes = BytesBuilder(copy: false);
  late final StreamSubscription<List<int>> _subscription;

  Future<String> get result => _completion.future;

  Future<void> cancel() async {
    if (!_completion.isCompleted) _completion.complete('');
    await _subscription.cancel();
  }
}

Future<String> hashFile(String path) async =>
    (await sha256.bind(File(path).openRead()).first).toString();

Future<void> copyFilePreservingMode(String source, String target) async {
  if (await FileSystemEntity.type(source, followLinks: false) !=
      FileSystemEntityType.file) {
    throw FileSystemException('Expected a regular file, not a link', source);
  }
  if (await FileSystemEntity.type(target, followLinks: false) !=
      FileSystemEntityType.notFound) {
    throw FileSystemException('Frozen destination already exists', target);
  }
  await File(target).parent.create(recursive: true);
  await File(source).copy(target);
  await _copyPermissions(source, target);
}

Future<void> copyTree(String source, String target) async {
  final from = p.normalize(p.absolute(source));
  final to = p.normalize(p.absolute(target));
  if (await FileSystemEntity.type(from, followLinks: false) !=
      FileSystemEntityType.directory) {
    throw FileSystemException('Expected a directory, not a link', from);
  }
  if (await FileSystemEntity.type(to, followLinks: false) !=
      FileSystemEntityType.notFound) {
    throw FileSystemException('Frozen destination already exists', to);
  }
  final physicalSource = await Directory(from).resolveSymbolicLinks();
  final physicalTarget = await _physicalDestination(to);
  if (physicalSource == physicalTarget ||
      p.isWithin(physicalSource, physicalTarget)) {
    throw ArgumentError('Frozen destination must be outside its source');
  }
  await Directory(to).create(recursive: true);
  final entries = await Directory(from).list(followLinks: false).toList();
  entries.sort((a, b) => a.path.compareTo(b.path));
  for (final entry in entries) {
    final destination = p.join(to, p.basename(entry.path));
    if (entry is Directory) {
      await copyTree(entry.path, destination);
    } else if (entry is File) {
      await copyFilePreservingMode(entry.path, destination);
    } else {
      throw FileSystemException(
        'Unsupported frozen entry (links are not copied)',
        entry.path,
      );
    }
  }
  await _copyPermissions(from, to);
}

Future<String> _physicalDestination(String path) async {
  final missing = <String>[];
  var ancestor = path;
  while (await FileSystemEntity.type(ancestor, followLinks: false) ==
      FileSystemEntityType.notFound) {
    missing.add(p.basename(ancestor));
    final parent = p.dirname(ancestor);
    if (parent == ancestor) {
      throw FileSystemException('Cannot resolve destination ancestor', path);
    }
    ancestor = parent;
  }
  final resolved = await Directory(ancestor).resolveSymbolicLinks();
  return p.joinAll([resolved, ...missing.reversed]);
}

Future<void> _copyPermissions(String source, String target) async {
  if (!Platform.isWindows) {
    final mode = (await FileStat.stat(source)).mode & 0x1ff;
    await runCommand(['chmod', mode.toRadixString(8), target]);
  }
}

Future<Map<String, Object?>> machineInfo() async {
  final target = RegExp(r'on "([^"]+)"').firstMatch(Platform.version)?.group(1);
  if (target == null) throw StateError('Cannot determine host architecture');
  final architecture = target.substring(target.lastIndexOf('_') + 1);
  late String release;
  late String cpu;
  late int memory;
  if (Platform.isMacOS) {
    release = (await runCommand(['uname', '-r'])).stdout.toString().trim();
    cpu = (await runCommand([
      'sysctl',
      '-n',
      'machdep.cpu.brand_string',
    ])).stdout.toString().trim();
    memory = int.parse(
      (await runCommand([
        'sysctl',
        '-n',
        'hw.memsize',
      ])).stdout.toString().trim(),
    );
  } else if (Platform.isLinux) {
    release = (await runCommand(['uname', '-r'])).stdout.toString().trim();
    final info = await File('/proc/cpuinfo').readAsString();
    cpu =
        RegExp(
          r'^(?:model name|Hardware|Processor)\s*:\s*(.+)$',
          multiLine: true,
        ).firstMatch(info)?.group(1)?.trim() ??
        architecture;
    final mem = RegExp(
      r'^MemTotal:\s+(\d+)\s+kB',
      multiLine: true,
    ).firstMatch(await File('/proc/meminfo').readAsString());
    if (mem == null) throw StateError('Cannot read host memory');
    memory = int.parse(mem.group(1)!) * 1024;
  } else if (Platform.isWindows) {
    final result = await runCommand([
      'powershell.exe',
      '-NoProfile',
      '-NonInteractive',
      '-Command',
      r'$cpu = Get-CimInstance Win32_Processor | Select-Object -First 1; '
          r'$system = Get-CimInstance Win32_ComputerSystem; '
          r'$os = Get-CimInstance Win32_OperatingSystem; '
          r'@{cpu=$cpu.Name; memoryBytes=$system.TotalPhysicalMemory; release=$os.Version} | ConvertTo-Json -Compress',
    ]);
    final values = jsonDecode(result.stdout as String) as Map<String, dynamic>;
    cpu = (values['cpu'] as String).trim();
    release = values['release'] as String;
    memory = (values['memoryBytes'] as num).toInt();
  } else {
    throw UnsupportedError(
      'Unsupported benchmark host: ${Platform.operatingSystem}',
    );
  }
  if (cpu.isEmpty || release.isEmpty || memory <= 0) {
    throw StateError('Incomplete host metadata');
  }
  return {
    'platform': Platform.isMacOS
        ? 'darwin'
        : (Platform.isWindows ? 'win32' : Platform.operatingSystem),
    'arch': architecture,
    'release': release,
    'cpu': cpu,
    'logicalCpus': Platform.numberOfProcessors,
    'memoryBytes': memory,
    'totalMemoryBytes': memory,
    'hostname': Platform.localHostname,
  };
}
