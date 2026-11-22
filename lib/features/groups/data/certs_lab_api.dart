import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/providers/auth_providers.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/current_workspace.dart';
import '../domain/hardware_models.dart';
import '../presentation/providers/group_providers.dart';

/// Certifications (project) and lab booking (group) — migration 0009.

const certStatusLabels = <String, String>{
  'planned': 'مخططة',
  'booked': 'المعمل اتحجز',
  'testing': 'تحت الاختبار',
  'passed': 'اتعتمدت',
  'failed': 'فشلت',
  'expired': 'انتهت',
};

class Certification {
  const Certification({
    required this.id,
    required this.standard,
    required this.status,
    required this.overdue,
    required this.expiring,
    this.region,
    this.lab,
    this.bomRev,
    this.dueAt,
    this.certifiedAt,
    this.expiresAt,
    this.certificateNumber,
    this.note,
  });

  final String id;
  final String standard;
  final String status;
  final bool overdue;
  final bool expiring;
  final String? region;
  final String? lab;
  final String? bomRev;
  final String? dueAt;
  final String? certifiedAt;
  final String? expiresAt;
  final String? certificateNumber;
  final String? note;

  String get statusLabel => certStatusLabels[status] ?? status;

  factory Certification.fromJson(Map<String, dynamic> json) => Certification(
        id: '${json['id']}',
        standard: '${json['standard'] ?? ''}',
        status: '${json['status'] ?? 'planned'}',
        overdue: json['overdue'] == true,
        expiring: json['expiring'] == true,
        region: json['region'] as String?,
        lab: json['lab'] as String?,
        bomRev: json['bom_rev'] as String?,
        dueAt: json['due_at'] as String?,
        certifiedAt: json['certified_at'] as String?,
        expiresAt: json['expires_at'] as String?,
        certificateNumber: json['certificate_number'] as String?,
        note: json['note'] as String?,
      );
}

class Certifications {
  const Certifications({required this.certs, required this.canManage});
  final List<Certification> certs;
  final bool canManage;
}

class LabAsset {
  const LabAsset({required this.id, required this.name, required this.archived, this.kind, this.location});
  final String id;
  final String name;
  final bool archived;
  final String? kind;
  final String? location;

  factory LabAsset.fromJson(Map<String, dynamic> json) => LabAsset(
        id: '${json['id']}',
        name: '${json['name'] ?? ''}',
        archived: json['archived'] == true,
        kind: json['kind'] as String?,
        location: json['location'] as String?,
      );
}

class LabAssets {
  const LabAssets({required this.assets, required this.canManage, required this.canBook});
  final List<LabAsset> assets;
  final bool canManage;
  final bool canBook;

  List<LabAsset> get live => assets.where((a) => !a.archived).toList(growable: false);
}

class LabBooking {
  const LabBooking({
    required this.id,
    required this.assetName,
    required this.startsAt,
    required this.endsAt,
    required this.mine,
    required this.private,
    this.by,
    this.projectName,
    this.purpose,
  });

  final String id;
  final String assetName;
  final DateTime startsAt;
  final DateTime endsAt;
  final bool mine;

  /// For a private project the caller cannot see: "busy", nothing more.
  final bool private;
  final String? by;
  final String? projectName;
  final String? purpose;

  factory LabBooking.fromJson(Map<String, dynamic> json) => LabBooking(
        id: '${json['id']}',
        assetName: '${json['asset_name'] ?? ''}',
        startsAt: DateTime.tryParse('${json['starts_at']}')?.toLocal() ?? DateTime(2000),
        endsAt: DateTime.tryParse('${json['ends_at']}')?.toLocal() ?? DateTime(2000),
        mine: json['mine'] == true,
        private: json['private'] == true,
        by: json['by'] as String?,
        projectName: json['project_name'] as String?,
        purpose: json['purpose'] as String?,
      );
}

class LabBookings {
  const LabBookings({required this.bookings, required this.canManage});
  final List<LabBooking> bookings;
  final bool canManage;
}

class CertsLabApi {
  CertsLabApi(this._api, this._workspace);
  final ApiClient _api;
  final CurrentWorkspace _workspace;

  static String _seg(String v) => Uri.encodeComponent(v);
  String _hw(String gid, String pid) => '/v1/groups/${_seg(gid)}/projects/${_seg(pid)}/hw';
  String _lab(String gid) => '/v1/groups/${_seg(gid)}/lab';

  Future<Map<String, dynamic>> _call(String op, String method, String path, [Object? body]) =>
      _api.run(op, () async {
        await _workspace.resolve();
        return switch (method) {
          'GET' => _api.get(path),
          'POST' => _api.post(path, body: body ?? const <String, dynamic>{}),
          _ => _api.patch(path, body: body),
        };
      });

  static Certifications _certs(Map<String, dynamic> p) => Certifications(
        certs: hwList(p['certs']).map(Certification.fromJson).toList(),
        canManage: p['can_manage'] == true,
      );

  Future<Certifications> certs(String gid, String pid) async =>
      _certs(await _call('certs.list', 'GET', '${_hw(gid, pid)}/certs'));

  Future<void> createCert(String gid, String pid, Map<String, dynamic> body) =>
      _call('certs.create', 'POST', '${_hw(gid, pid)}/certs', body);

  Future<void> updateCert(String gid, String pid, String cid, Map<String, dynamic> body) =>
      _call('certs.update', 'PATCH', '${_hw(gid, pid)}/certs/${_seg(cid)}', body);

  Future<LabAssets> assets(String gid) async {
    final p = await _call('lab.assets', 'GET', '${_lab(gid)}/assets');
    return LabAssets(
      assets: hwList(p['assets']).map(LabAsset.fromJson).toList(),
      canManage: p['can_manage'] == true,
      canBook: p['can_book'] == true,
    );
  }

  Future<void> addAsset(String gid, {required String name, String? kind, String? location}) =>
      _call('lab.asset_add', 'POST', '${_lab(gid)}/assets', {
        'name': name,
        if (kind != null && kind.isNotEmpty) 'kind': kind,
        if (location != null && location.isNotEmpty) 'location': location,
      });

  Future<void> archiveAsset(String gid, String aid) =>
      _call('lab.asset_archive', 'PATCH', '${_lab(gid)}/assets/${_seg(aid)}', {'archived': true});

  Future<LabBookings> bookings(String gid) async {
    final p = await _call('lab.bookings', 'GET', '${_lab(gid)}/bookings');
    return LabBookings(
      bookings: hwList(p['bookings']).map(LabBooking.fromJson).toList(),
      canManage: p['can_manage'] == true,
    );
  }

  Future<void> book(String gid,
          {required String assetId, required DateTime start, required DateTime end, String? projectId, String? purpose}) =>
      _call('lab.book', 'POST', '${_lab(gid)}/bookings', {
        'asset_id': assetId,
        'starts_at': _rfc3339(start),
        'ends_at': _rfc3339(end),
        if (projectId != null) 'project_id': projectId,
        if (purpose != null && purpose.isNotEmpty) 'purpose': purpose,
      });

  /// UTC, seconds precision: "2026-12-01T07:00:00Z".
  static String _rfc3339(DateTime t) => '${t.toUtc().toIso8601String().split('.').first}Z';

  Future<void> cancelBooking(String gid, String id) =>
      _call('lab.cancel', 'POST', '${_lab(gid)}/bookings/${_seg(id)}/cancel');
}

final certsLabApiProvider = Provider<CertsLabApi>(
  (ref) => CertsLabApi(ref.watch(apiClientProvider), ref.watch(currentWorkspaceProvider)),
);

void _bind(Ref ref) => ref.watch(authNotifierProvider.select((state) => state.value?.id));

final certsProvider = FutureProvider.family<Certifications, ProjectKey>((ref, key) {
  _bind(ref);
  return ref.watch(certsLabApiProvider).certs(key.gid, key.pid);
});

final labAssetsProvider = FutureProvider.family<LabAssets, String>((ref, gid) {
  _bind(ref);
  return ref.watch(certsLabApiProvider).assets(gid);
});

final labBookingsProvider = FutureProvider.family<LabBookings, String>((ref, gid) {
  _bind(ref);
  return ref.watch(certsLabApiProvider).bookings(gid);
});
