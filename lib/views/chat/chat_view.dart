import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mess_manager/controllers/auth_controller.dart';
import 'package:mess_manager/controllers/chat_controller.dart';
import 'package:mess_manager/controllers/mess_controller.dart';
import 'package:mess_manager/models/chat_message_model.dart';
import 'package:mess_manager/models/user_model.dart';
import 'package:mess_manager/app/theme/app_theme.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';

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

  /// Tracked mentions: uid -> username
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
  }

  @override
  void dispose() {
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
    final mention = '@${member.username} ';

    _mentionedUsers[member.uid] = member.username;

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
              m.username.toLowerCase().contains(_mentionQuery),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mess Chat'),
        actions: [
          IconButton(
            icon: const Icon(Icons.photo_rounded),
            onPressed: () => chatController.sendImage(),
            tooltip: 'Send Photo',
          ),
          IconButton(
            icon: const Icon(Icons.attach_file_rounded),
            onPressed: () => chatController.sendDocument(),
            tooltip: 'Send Document',
          ),
        ],
      ),
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
                  return _MessageBubble(message: msg, isMe: isMe);
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
                      member.username[0].toUpperCase(),
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
                        '@${member.username}',
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
}

class _MessageBubble extends StatelessWidget {
  final ChatMessageModel message;
  final bool isMe;

  const _MessageBubble({required this.message, required this.isMe});

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
            padding: message.isImage
                ? const EdgeInsets.all(4)
                : const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: isMe ? AppTheme.primaryColor : AppTheme.cardColor,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: Radius.circular(isMe ? 16 : 4),
                bottomRight: Radius.circular(isMe ? 4 : 16),
              ),
            ),
            child: _buildContent(),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              DateFormat('hh:mm a').format(message.createdAt),
              style: const TextStyle(
                fontSize: 10,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (message.isImage) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: CachedNetworkImage(
          imageUrl: message.content,
          width: 200,
          fit: BoxFit.cover,
          placeholder: (_, _) => const SizedBox(
            width: 200,
            height: 150,
            child: Center(child: CircularProgressIndicator()),
          ),
          errorWidget: (_, _, _) => const SizedBox(
            width: 200,
            height: 150,
            child: Icon(Icons.broken_image, color: AppTheme.textSecondary),
          ),
        ),
      );
    }

    if (message.isDocument) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.insert_drive_file, color: Colors.white70, size: 20),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              message.fileName ?? 'Document',
              style: TextStyle(
                color: isMe ? Colors.white : AppTheme.textPrimary,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ],
      );
    }

    // Text with @mention highlighting
    return _buildRichText();
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
}
