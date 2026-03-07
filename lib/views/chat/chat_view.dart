import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mess_manager/controllers/auth_controller.dart';
import 'package:mess_manager/controllers/chat_controller.dart';
import 'package:mess_manager/controllers/mess_controller.dart';
import 'package:mess_manager/models/chat_message_model.dart';
import 'package:mess_manager/models/user_model.dart';
import 'package:mess_manager/app/theme/app_theme.dart';
import 'package:intl/intl.dart';

class ChatView extends StatefulWidget {
  const ChatView({super.key});

  @override
  State<ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends State<ChatView> {
  final chatController = Get.find<ChatController>();
  final authController = Get.find<AuthController>();
  final messController = Get.find<MessController>();

  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  Timer? _markReadTimer;

  /// Tracked mentions: uid -> name
  final Map<String, String> _mentionedUsers = {};

  /// Whether the @mention popup is visible.
  bool _showMentionPopup = false;

  /// Filter query typed after '@'.
  String _mentionQuery = '';

  /// Position of the '@' that triggered the popup.
  int _mentionStartIndex = -1;

  @override
  void initState() {
    super.initState();
    _messageController.addListener(_onTextChanged);
    // Mark existing messages as read when entering chat
    chatController.markVisibleMessagesAsRead();
    // Periodically mark new messages as read while on this screen
    _markReadTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => chatController.markVisibleMessagesAsRead(),
    );
  }

  @override
  void dispose() {
    _markReadTimer?.cancel();
    _messageController.removeListener(_onTextChanged);
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final text = _messageController.text;
    final cursorPos = _messageController.selection.baseOffset;

    if (cursorPos < 0 || cursorPos > text.length) {
      _hideMentionPopup();
      return;
    }

    // Look backwards from cursor for a '@' that is either at start or after a space
    int atIndex = -1;
    for (int i = cursorPos - 1; i >= 0; i--) {
      if (text[i] == ' ' || text[i] == '\n') break;
      if (text[i] == '@') {
        if (i == 0 || text[i - 1] == ' ' || text[i - 1] == '\n') {
          atIndex = i;
        }
        break;
      }
    }

    if (atIndex >= 0) {
      final query = text.substring(atIndex + 1, cursorPos).toLowerCase();
      setState(() {
        _showMentionPopup = true;
        _mentionQuery = query;
        _mentionStartIndex = atIndex;
      });
    } else {
      _hideMentionPopup();
    }
  }

  void _hideMentionPopup() {
    if (_showMentionPopup) {
      setState(() {
        _showMentionPopup = false;
        _mentionQuery = '';
        _mentionStartIndex = -1;
      });
    }
  }

  void _selectMention(UserModel member) {
    final text = _messageController.text;
    final cursorPos = _messageController.selection.baseOffset;
    final before = text.substring(0, _mentionStartIndex);
    final after = text.substring(cursorPos);
    final mention = '@${member.name} ';

    _mentionedUsers[member.uid] = member.name;

    final newText = '$before$mention$after';
    _messageController.text = newText;
    _messageController.selection = TextSelection.collapsed(
      offset: _mentionStartIndex + mention.length,
    );
    _hideMentionPopup();
  }

  void _sendMessage() {
    final text = _messageController.text;
    if (text.trim().isEmpty) return;

    // Extract mentioned UIDs that are actually in the final text
    final mentionUids = <String>[];
    for (final entry in _mentionedUsers.entries) {
      if (text.contains('@${entry.value}')) {
        mentionUids.add(entry.key);
      }
    }

    chatController.sendTextMessage(text, mentions: mentionUids);
    _messageController.clear();
    _mentionedUsers.clear();
    _hideMentionPopup();
  }

  List<UserModel> get _filteredMembers {
    final members = messController.messMembers;
    final currentUid = authController.currentUser.value?.uid;
    if (_mentionQuery.isEmpty) {
      return members.where((m) => m.uid != currentUid).toList();
    }
    return members
        .where(
          (m) =>
              m.uid != currentUid &&
              m.name.toLowerCase().contains(_mentionQuery),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mess Chat')),
      body: Column(
        children: [
          // Messages list
          Expanded(
            child: Obx(() {
              final messages = chatController.messages;

              if (messages.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.chat_bubble_outline,
                        size: 64,
                        color: AppTheme.textSecondary.withValues(alpha: 0.5),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'No messages yet',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Start a conversation!',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                reverse: true,
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final msg = messages[index];
                  final isMe =
                      msg.senderId == authController.currentUser.value?.uid;
                  final totalMembers = messController.messMembers.length;
                  return GestureDetector(
                    onLongPress: () => _showMessageOptions(msg, isMe),
                    child: _MessageBubble(
                      message: msg,
                      isMe: isMe,
                      totalMembers: totalMembers,
                    ),
                  );
                },
              );
            }),
          ),

          // Mention popup
          if (_showMentionPopup) _buildMentionPopup(),

          // Send bar
          Obx(
            () => Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: SafeArea(
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: InputDecoration(
                          hintText: 'Type a message... use @ to mention',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: AppTheme.cardColor,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 10,
                          ),
                        ),
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: chatController.isSending.value
                            ? AppTheme.textSecondary
                            : AppTheme.primaryColor,
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        onPressed: chatController.isSending.value
                            ? null
                            : _sendMessage,
                        icon: chatController.isSending.value
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(
                                Icons.send_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMentionPopup() {
    final filtered = _filteredMembers;
    if (filtered.isEmpty) return const SizedBox.shrink();

    return Container(
      constraints: const BoxConstraints(maxHeight: 180),
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: ListView.builder(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(vertical: 4),
        itemCount: filtered.length,
        itemBuilder: (context, index) {
          final member = filtered[index];
          return InkWell(
            onTap: () => _selectMention(member),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: AppTheme.primaryColor.withValues(
                      alpha: 0.2,
                    ),
                    child: Text(
                      member.name.isNotEmpty
                          ? member.name[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryColor,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        member.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        member.email,
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showMessageOptions(ChatMessageModel msg, bool isMe) {
    final canEdit = chatController.canEditMessage(msg);
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              decoration: BoxDecoration(
                color: AppTheme.textSecondary.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: const Icon(
                Icons.info_outline,
                color: AppTheme.primaryColor,
              ),
              title: const Text(
                'Info',
                style: TextStyle(color: AppTheme.textPrimary),
              ),
              subtitle: const Text(
                'See who has read this message',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
              ),
              onTap: () {
                Navigator.pop(sheetContext);
                _showMessageInfo(msg);
              },
            ),
            if (isMe && canEdit)
              ListTile(
                leading: const Icon(
                  Icons.edit_outlined,
                  color: AppTheme.secondaryColor,
                ),
                title: const Text(
                  'Edit',
                  style: TextStyle(color: AppTheme.textPrimary),
                ),
                subtitle: Text(
                  'Can edit within 30 min of sending (${_remainingEditTime(msg)})',
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                  ),
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  // Delay to let bottom sheet fully dismiss before showing dialog
                  Future.delayed(const Duration(milliseconds: 300), () {
                    if (mounted) _showEditMessageDialog(msg);
                  });
                },
              ),
            if (isMe)
              ListTile(
                leading: const Icon(
                  Icons.delete_outline,
                  color: AppTheme.errorColor,
                ),
                title: const Text(
                  'Delete',
                  style: TextStyle(color: AppTheme.errorColor),
                ),
                subtitle: const Text(
                  'Permanently delete this message',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  Future.delayed(const Duration(milliseconds: 300), () {
                    if (mounted) _showDeleteConfirmation(msg);
                  });
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  String _remainingEditTime(ChatMessageModel msg) {
    final elapsed = DateTime.now().difference(msg.createdAt).inMinutes;
    final remaining = 30 - elapsed;
    if (remaining <= 0) return 'expired';
    return '$remaining min left';
  }

  void _showEditMessageDialog(ChatMessageModel msg) {
    final editController = TextEditingController(text: msg.content);
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        title: const Text(
          'Edit Message',
          style: TextStyle(color: AppTheme.textPrimary),
        ),
        content: TextField(
          controller: editController,
          autofocus: true,
          maxLines: 4,
          minLines: 1,
          style: const TextStyle(color: AppTheme.textPrimary),
          decoration: InputDecoration(
            hintText: 'Edit your message...',
            filled: true,
            fillColor: AppTheme.cardColor,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final newText = editController.text.trim();
              Navigator.pop(dialogContext);
              if (newText.isNotEmpty && newText != msg.content) {
                chatController.editMessage(msg.messageId, newText);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    ).then((_) {
      // Defer disposal to next frame so the TextField inside the dialog
      // has fully unmounted before we dispose its controller.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        editController.dispose();
      });
    });
  }

  void _showDeleteConfirmation(ChatMessageModel msg) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        title: const Text(
          'Delete Message',
          style: TextStyle(color: AppTheme.textPrimary),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Are you sure you want to delete this message? This action cannot be undone.',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.cardColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                msg.content,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
            ),
            onPressed: () {
              Navigator.pop(dialogContext);
              chatController.deleteMessage(msg.messageId);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showMessageInfo(ChatMessageModel msg) {
    final members = messController.messMembers;
    final readEntries = msg.readBy.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));

    // Members who haven't read (exclude sender)
    final readUids = msg.readBy.keys.toSet();
    final unreadMembers = members
        .where((m) => m.uid != msg.senderId && !readUids.contains(m.uid))
        .toList();

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceColor,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.6,
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppTheme.textSecondary.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const Text(
                'Message Info',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.cardColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  msg.content,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Read by section
              Row(
                children: [
                  const Icon(
                    Icons.done_all,
                    size: 16,
                    color: Colors.blueAccent,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Read by (${readEntries.length})',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (readEntries.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(left: 4),
                  child: Text(
                    'No one has read this yet',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                )
              else
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      ...readEntries.map((e) {
                        final member = members
                            .where((m) => m.uid == e.key)
                            .firstOrNull;
                        final name = member?.name ?? e.key;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 16,
                                backgroundColor: AppTheme.successColor
                                    .withValues(alpha: 0.2),
                                child: Text(
                                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.successColor,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                              ),
                              Text(
                                DateFormat('MMM dd, hh:mm a').format(e.value),
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                      // Unread section
                      if (unreadMembers.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Icon(
                              Icons.done,
                              size: 16,
                              color: AppTheme.textSecondary.withValues(
                                alpha: 0.5,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Not yet read (${unreadMembers.length})',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ...unreadMembers.map(
                          (m) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 16,
                                  backgroundColor: AppTheme.textSecondary
                                      .withValues(alpha: 0.15),
                                  child: Text(
                                    m.name.isNotEmpty
                                        ? m.name[0].toUpperCase()
                                        : '?',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.textSecondary,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  m.name,
                                  style: const TextStyle(
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessageModel message;
  final bool isMe;
  final int totalMembers;

  const _MessageBubble({
    required this.message,
    required this.isMe,
    required this.totalMembers,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: isMe
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          if (!isMe)
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 4),
              child: Text(
                message.senderName,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.75,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: isMe ? AppTheme.primaryColor : AppTheme.cardColor,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: Radius.circular(isMe ? 16 : 4),
                bottomRight: Radius.circular(isMe ? 4 : 16),
              ),
            ),
            child: _buildRichText(),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (message.isEdited) ...[
                  Text(
                    'edited',
                    style: TextStyle(
                      fontSize: 10,
                      fontStyle: FontStyle.italic,
                      color: AppTheme.textSecondary.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(width: 4),
                ],
                Text(
                  DateFormat('hh:mm a').format(message.createdAt),
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppTheme.textSecondary,
                  ),
                ),
                if (isMe) ...[const SizedBox(width: 4), _buildReadTick()],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRichText() {
    final text = message.content;
    final baseColor = isMe ? Colors.white : AppTheme.textPrimary;
    final mentionColor = isMe ? Colors.yellowAccent : AppTheme.accentColor;

    // Find @mentions using regex
    final mentionRegex = RegExp(r'@(\w+)');
    final matches = mentionRegex.allMatches(text).toList();

    if (matches.isEmpty) {
      return Text(text, style: TextStyle(color: baseColor, fontSize: 15));
    }

    final spans = <TextSpan>[];
    int lastEnd = 0;

    for (final match in matches) {
      // Add text before the mention
      if (match.start > lastEnd) {
        spans.add(
          TextSpan(
            text: text.substring(lastEnd, match.start),
            style: TextStyle(color: baseColor, fontSize: 15),
          ),
        );
      }

      // Add the mention with highlight
      spans.add(
        TextSpan(
          text: match.group(0),
          style: TextStyle(
            color: mentionColor,
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
        ),
      );

      lastEnd = match.end;
    }

    // Add remaining text
    if (lastEnd < text.length) {
      spans.add(
        TextSpan(
          text: text.substring(lastEnd),
          style: TextStyle(color: baseColor, fontSize: 15),
        ),
      );
    }

    return RichText(text: TextSpan(children: spans));
  }

  Widget _buildReadTick() {
    // Everyone except sender
    final othersCount = totalMembers - 1;
    final readCount = message.readBy.length;
    final allRead = othersCount > 0 && readCount >= othersCount;
    final someRead = readCount > 0;

    if (allRead) {
      return const Icon(Icons.done_all, size: 14, color: Colors.blueAccent);
    } else if (someRead) {
      return Icon(
        Icons.done_all,
        size: 14,
        color: AppTheme.textSecondary.withValues(alpha: 0.5),
      );
    } else {
      return Icon(
        Icons.done,
        size: 14,
        color: AppTheme.textSecondary.withValues(alpha: 0.5),
      );
    }
  }
}
