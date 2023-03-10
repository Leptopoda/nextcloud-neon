import 'package:nextcloud/nextcloud.dart';
import 'package:test/test.dart';

import 'helper.dart';

Future main() async {
  await run(await getDockerImage());
}

Future run(final DockerImage image) async {
  group('user_status', () {
    late DockerContainer container;
    late TestNextcloudClient client;
    setUp(() async {
      container = await getDockerContainer(image);
      client = await getTestClient(container);
    });
    tearDown(() => container.destroy());

    test('Find all predefined statuses', () async {
      final expectedStatusIDs = ['meeting', 'commuting', 'remote-work', 'sick-leave', 'vacationing'];
      final response = await client.userStatus.getPredefinedStatuses();
      expect(response.ocs.data, hasLength(5));
      final responseIDs = response.ocs.data.map((final status) => status.id);
      expect(expectedStatusIDs.map(responseIDs.contains).contains(false), false);
      for (final status in response.ocs.data) {
        expect(status.icon, isNotNull);
        expect(status.message, isNotNull);
      }

      final meeting = response.ocs.data.singleWhere((final s) => s.id == 'meeting').clearAt!.userStatusClearAt0!;
      expect(meeting.type, NextcloudUserStatusClearAt0_Type.period);
      expect(meeting.time.$int, 3600);

      final commuting = response.ocs.data.singleWhere((final s) => s.id == 'commuting').clearAt!.userStatusClearAt0!;
      expect(commuting.type, NextcloudUserStatusClearAt0_Type.period);
      expect(commuting.time.$int, 1800);

      final remoteWork = response.ocs.data.singleWhere((final s) => s.id == 'remote-work').clearAt!.userStatusClearAt0!;
      expect(remoteWork.type, NextcloudUserStatusClearAt0_Type.endOf);
      expect(remoteWork.time.userStatusClearAt0Time0, NextcloudUserStatusClearAt0_Time0.day);

      final sickLeave = response.ocs.data.singleWhere((final s) => s.id == 'sick-leave').clearAt!.userStatusClearAt0!;
      expect(sickLeave.type, NextcloudUserStatusClearAt0_Type.endOf);
      expect(sickLeave.time.userStatusClearAt0Time0, NextcloudUserStatusClearAt0_Time0.day);

      final vacationing = response.ocs.data.singleWhere((final s) => s.id == 'vacationing').clearAt;
      expect(vacationing, null);
    });

    test('Set status', () async {
      final response = await client.userStatus.setStatus(statusType: NextcloudUserStatusType.online);

      expect(response.ocs.data.userId, 'user1');
      expect(response.ocs.data.message, null);
      expect(response.ocs.data.messageId, null);
      expect(response.ocs.data.messageIsPredefined, false);
      expect(response.ocs.data.icon, null);
      expect(response.ocs.data.clearAt, null);
      expect(response.ocs.data.status, NextcloudUserStatusType.online);
      expect(response.ocs.data.statusIsUserDefined, true);
    });

    test('Get status', () async {
      // There seems to be a bug in Nextcloud which makes getting the status fail before it has been set once.
      // The error message from Nextcloud is "Could not create folder"
      await client.userStatus.setStatus(statusType: NextcloudUserStatusType.online);

      final response = await client.userStatus.getStatus();
      expect(response.ocs.data.userId, 'user1');
      expect(response.ocs.data.message, null);
      expect(response.ocs.data.messageId, null);
      expect(response.ocs.data.messageIsPredefined, false);
      expect(response.ocs.data.icon, null);
      expect(response.ocs.data.clearAt, null);
      expect(response.ocs.data.status, NextcloudUserStatusType.online);
      expect(response.ocs.data.statusIsUserDefined, true);
    });

    test('Find all statuses', () async {
      var response = await client.userStatus.getPublicStatuses();
      expect(response.ocs.data, hasLength(0));

      await client.userStatus.setStatus(statusType: NextcloudUserStatusType.online);

      response = await client.userStatus.getPublicStatuses();
      expect(response.ocs.data, hasLength(1));
      expect(response.ocs.data[0].userId, 'user1');
      expect(response.ocs.data[0].message, null);
      expect(response.ocs.data[0].icon, null);
      expect(response.ocs.data[0].clearAt, null);
      expect(response.ocs.data[0].status, NextcloudUserStatusType.online);
    });

    test('Find status', () async {
      // Same as getting status
      await client.userStatus.setStatus(statusType: NextcloudUserStatusType.online);

      final response = await client.userStatus.getPublicStatus(userId: 'user1');
      expect(response.ocs.data.userId, 'user1');
      expect(response.ocs.data.message, null);
      expect(response.ocs.data.icon, null);
      expect(response.ocs.data.clearAt, null);
      expect(response.ocs.data.status, NextcloudUserStatusType.online);
    });

    test('Set predefined message', () async {
      final clearAt = DateTime.now().millisecondsSinceEpoch ~/ 1000 + 60;
      final response = await client.userStatus.setPredefinedMessage(
        messageId: 'meeting',
        clearAt: clearAt,
      );
      expect(response.ocs.data.userId, 'user1');
      expect(response.ocs.data.message, null);
      expect(response.ocs.data.messageId, 'meeting');
      expect(response.ocs.data.messageIsPredefined, true);
      expect(response.ocs.data.icon, null);
      expect(response.ocs.data.clearAt!.$int, clearAt);
      expect(response.ocs.data.status, NextcloudUserStatusType.offline);
      expect(response.ocs.data.statusIsUserDefined, false);
    });

    test('Set custom message', () async {
      final clearAt = DateTime.now().millisecondsSinceEpoch ~/ 1000 + 60;
      final response = await client.userStatus.setCustomMessage(
        statusIcon: '😀',
        message: 'bla',
        clearAt: clearAt,
      );
      expect(response.ocs.data.userId, 'user1');
      expect(response.ocs.data.message, 'bla');
      expect(response.ocs.data.messageId, null);
      expect(response.ocs.data.messageIsPredefined, false);
      expect(response.ocs.data.icon, '😀');
      expect(response.ocs.data.clearAt!.$int, clearAt);
      expect(response.ocs.data.status, NextcloudUserStatusType.offline);
      expect(response.ocs.data.statusIsUserDefined, false);
    });

    test('Clear message', () async {
      final clearAt = DateTime.now().millisecondsSinceEpoch ~/ 1000 + 60;
      await client.userStatus.setCustomMessage(
        statusIcon: '😀',
        message: 'bla',
        clearAt: clearAt,
      );
      await client.userStatus.clearMessage();

      final response = await client.userStatus.getStatus();
      expect(response.ocs.data.userId, 'user1');
      expect(response.ocs.data.message, null);
      expect(response.ocs.data.messageId, null);
      expect(response.ocs.data.messageIsPredefined, false);
      expect(response.ocs.data.icon, null);
      expect(response.ocs.data.clearAt, null);
      expect(response.ocs.data.status, NextcloudUserStatusType.offline);
      expect(response.ocs.data.statusIsUserDefined, false);
    });

    test('Heartbeat', () async {
      final response = await client.userStatus.heartbeat(status: NextcloudUserStatusType.online);
      expect(response.userId, 'user1');
      expect(response.message, null);
      expect(response.messageId, null);
      expect(response.messageIsPredefined, false);
      expect(response.icon, null);
      expect(response.clearAt, null);
      expect(response.status, NextcloudUserStatusType.online);
      expect(response.statusIsUserDefined, false);
    });
  });
}
