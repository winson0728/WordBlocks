import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../platform/reminders.dart';
import '../sync/sync_service.dart';

/// Account sync, daily reminder and home-screen widget.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('設定')),
      body: ListenableBuilder(
        listenable: Listenable.merge([scope.store, scope.sync]),
        builder: (context, _) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            Text('帳號同步', style: text.titleMedium),
            const SizedBox(height: 8),
            const _AccountCard(),
            const SizedBox(height: 24),
            Text('每日提醒', style: text.titleMedium),
            const SizedBox(height: 8),
            const _ReminderCard(),
            const SizedBox(height: 24),
            Text('桌面小工具', style: text.titleMedium),
            const SizedBox(height: 8),
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('在手機桌面空白處長按 → 小工具 → 找到「字根工坊」→ 拖到桌面。'
                    '小工具每天會換一個字根，點一下就會打開 App。'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReminderCard extends StatelessWidget {
  const _ReminderCard();

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context).store;
    final m = store.reminderMinute;
    final time = TimeOfDay(hour: m ~/ 60, minute: m % 60);
    final messenger = ScaffoldMessenger.of(context);

    Future<void> apply(bool on, int minute) async {
      try {
        if (on) {
          final ok = await Reminders.enable(minute);
          if (!ok) {
            messenger.showSnackBar(const SnackBar(content: Text('沒有通知權限。請到手機的設定 → 應用程式 → 字根工坊 開啟通知。')));
            await store.setReminder(on: false, minute: minute);
            return;
          }
        } else {
          await Reminders.disable();
        }
        await store.setReminder(on: on, minute: minute);
      } catch (e) {
        messenger.showSnackBar(SnackBar(content: Text('提醒設定失敗：$e')));
      }
    }

    return Card(
      child: Column(children: [
        SwitchListTile(
          title: const Text('每天提醒我複習'),
          subtitle: Text(Reminders.supported ? '時間到會跳出一則通知' : '只有 Android 手機支援'),
          value: store.reminderOn,
          onChanged: Reminders.supported ? (v) => apply(v, m) : null,
        ),
        ListTile(
          enabled: store.reminderOn,
          title: const Text('提醒時間'),
          trailing: Text(time.format(context), style: Theme.of(context).textTheme.titleMedium),
          onTap: () async {
            final picked = await showTimePicker(context: context, initialTime: time);
            if (picked != null) await apply(true, picked.hour * 60 + picked.minute);
          },
        ),
      ]),
    );
  }
}

class _AccountCard extends StatefulWidget {
  const _AccountCard();

  @override
  State<_AccountCard> createState() => _AccountCardState();
}

class _AccountCardState extends State<_AccountCard> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  String? _note;
  bool _busy = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _run(Future<String?> Function() action) async {
    setState(() {
      _busy = true;
      _note = null;
    });
    final note = await action();
    if (mounted) {
      setState(() {
        _busy = false;
        _note = note;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final sync = AppScope.of(context).sync;
    final text = Theme.of(context).textTheme;

    if (!sync.config.enabled) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('同步還沒設定。設定 Supabase 專案後（見 README 的「帳號同步」），'
              '就能用 Email 登入，讓手機和網頁版共用學習進度。目前進度只存在這支手機上。'),
        ),
      );
    }

    final email = sync.email;
    if (email != null) {
      final status = switch (sync.status) {
        SyncStatus.syncing => '同步中…',
        SyncStatus.error => sync.message ?? '同步失敗',
        _ when sync.lastSynced != null => '已同步 · ${TimeOfDay.fromDateTime(sync.lastSynced!).format(context)}',
        _ => '已登入',
      };
      return Card(
        child: Column(children: [
          ListTile(
            leading: const Icon(Icons.cloud_done_outlined),
            title: Text(email),
            subtitle: Text(status),
          ),
          OverflowBar(alignment: MainAxisAlignment.end, children: [
            TextButton(onPressed: sync.status == SyncStatus.syncing ? null : sync.syncNow, child: const Text('立即同步')),
            TextButton(onPressed: sync.signOut, child: const Text('登出')),
          ]),
        ]),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('登入後，手機和網頁版會共用學習進度。', style: text.bodyMedium),
          const SizedBox(height: 12),
          TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder(), isDense: true),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _password,
            obscureText: true,
            decoration: const InputDecoration(labelText: '密碼（至少 6 個字元）', border: OutlineInputBorder(), isDense: true),
          ),
          if (_note != null) ...[
            const SizedBox(height: 10),
            Text(_note!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: FilledButton(
                onPressed: _busy ? null : () => _run(() => sync.signIn(_email.text, _password.text)),
                child: const Text('登入'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                onPressed: _busy ? null : () => _run(() => sync.signUp(_email.text, _password.text)),
                child: const Text('建立帳號'),
              ),
            ),
          ]),
        ]),
      ),
    );
  }
}
