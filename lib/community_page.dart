import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:my_app/view_other_profile_page.dart';

/// Community feed for VietLove. Posts are text-only; profile photos are avatars.
/// NOTE: client-side filtering is a UX layer. Deploy server-side moderation and
/// restrictive Firestore rules before production to prevent direct-write bypass.
class CommunityPage extends StatefulWidget {
  final String languageCode;
  const CommunityPage({super.key, required this.languageCode});

  @override
  State<CommunityPage> createState() => _CommunityPageState();
}

class _CommunityPageState extends State<CommunityPage> {
  static const _pink = Color(0xFFC04491);
  static const _deep = Color(0xFF603B59);
  static const _pale = Color(0xFFF5E9F5);
  final _composer = TextEditingController();
  String? _feeling;
  bool _anonymous = false;
  bool _sending = false;
  String? _replyToId;
  String? _replyToName;
  bool get isVi => widget.languageCode == 'vi';
  String tr(String vi, String en) => isVi ? vi : en;
  User? get me => FirebaseAuth.instance.currentUser;
  CollectionReference<Map<String, dynamic>> get posts =>
      FirebaseFirestore.instance.collection('community_posts');

  // Bilingual starter blocklist. Add/remove terms to tune moderation.
  static const Set<String> _blockedWords = {
    // Vietnamese profanity, insults and degrading language.
    'địt','đụ','đéo','lồn','cặc','buồi','đm','đcm','dm','dcm','vcl','vl',
    'ngu','đần','đồ ngu','mất dạy','khốn nạn','súc vật','con chó','đĩ','điếm',
    'cút','hãm','chó chết','đồ khốn',
    // English profanity, insults and degrading language.
    'fuck','fucking','shit','bullshit','bitch','bastard','asshole','motherfucker',
    'stupid','idiot','moron','dumbass','dumb','jerk','loser','scumbag',
    'slut','whore','prick','dickhead','piece of shit',
  };

  static const Set<String> _blockedPhrases = {
    'kill yourself','go die','drop dead','chết đi','đi chết đi',
    'đồ ngu','đồ chó','đồ khốn','thằng ngu','con ngu',
  };

  String _fold(String input) {
    var s = input.toLowerCase();
    const replacements = {
      'à':'a','á':'a','ạ':'a','ả':'a','ã':'a','â':'a','ầ':'a','ấ':'a','ậ':'a','ẩ':'a','ẫ':'a','ă':'a','ằ':'a','ắ':'a','ặ':'a','ẳ':'a','ẵ':'a',
      'è':'e','é':'e','ẹ':'e','ẻ':'e','ẽ':'e','ê':'e','ề':'e','ế':'e','ệ':'e','ể':'e','ễ':'e',
      'ì':'i','í':'i','ị':'i','ỉ':'i','ĩ':'i','ò':'o','ó':'o','ọ':'o','ỏ':'o','õ':'o','ô':'o','ồ':'o','ố':'o','ộ':'o','ổ':'o','ỗ':'o','ơ':'o','ờ':'o','ớ':'o','ợ':'o','ở':'o','ỡ':'o',
      'ù':'u','ú':'u','ụ':'u','ủ':'u','ũ':'u','ư':'u','ừ':'u','ứ':'u','ự':'u','ử':'u','ữ':'u','ỳ':'y','ý':'y','ỵ':'y','ỷ':'y','ỹ':'y','đ':'d',
    };
    replacements.forEach((k,v) => s = s.replaceAll(k,v));
    return s;
  }

  bool _hasBlockedWords(String text) {
    final normalized = _fold(text)
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .trim();
    if (normalized.isEmpty) return false;
    final words = normalized.split(RegExp(r'\s+'));
    if (words.any((word) => _blockedWords.contains(word))) return true;

    for (final phrase in _blockedPhrases) {
      final normalizedPhrase = _fold(phrase)
          .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
          .trim();
      if (' $normalized '.contains(' $normalizedPhrase ')) return true;
    }

    // Detect simple punctuation/spacing obfuscation (e.g. s.t.u.p.i.d).
    final compact = normalized.replaceAll(' ', '');
    for (final term in _blockedWords) {
      final foldedTerm = _fold(term).replaceAll(RegExp(r'[^a-z0-9]+'), '');
      if (foldedTerm.length >= 5 && compact.contains(foldedTerm)) return true;
    }
    return false;
  }

  @override
  void dispose() {
    _composer.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>> _myProfile() async {
    final uid = me?.uid;
    if (uid == null) return {};
    final snap = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    return snap.data() ?? {};
  }

  Future<void> _sendPost() async {
    final text = _composer.text.trim();
    if (me == null || text.isEmpty || _sending) return;
    if (text.length > 3000) {
      _toast(tr('Bài viết tối đa 3.000 ký tự.','Posts can contain up to 3,000 characters.'));
      return;
    }
    if (_hasBlockedWords(text)) {
      _toast(tr('Nội dung có từ ngữ không phù hợp. Vui lòng chỉnh sửa trước khi đăng.','Your post contains language that is not allowed. Please edit it before posting.'));
      return;
    }
    setState(() => _sending = true);
    try {
      final p = await _myProfile();
      final name = (p['firstName'] ?? p['displayName'] ?? me!.displayName ?? tr('Thành viên VietLove','VietLove member')).toString();
      final photo = (p['mainPhotoUrl'] ?? p['photoUrl'] ?? me!.photoURL ?? '').toString();
      await posts.add({
        'userId': me!.uid,
        'authorName': _anonymous ? tr('Thành viên ẩn danh','Anonymous member') : name,
        'authorPhotoUrl': _anonymous ? '' : photo,
        'isAnonymous': _anonymous,
        'content': text,
        'feeling': _feeling ?? '',
        'createdAt': FieldValue.serverTimestamp(),
        'likeCount': 0,
        'commentCount': 0,
      });
      _composer.clear();
      setState(() { _feeling = null; _anonymous = false; });
      _toast(tr('Đã đăng câu chuyện của bạn. ❤️','Your story has been shared. ❤️'));
    } catch (e) {
      _toast(tr('Không thể đăng bài. Vui lòng thử lại.','Could not publish your post. Please try again.'));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _toggleLike(String postId) async {
    final uid = me?.uid;
    if (uid == null) return;
    final postRef = posts.doc(postId);
    final likeRef = postRef.collection('likes').doc(uid);
    try {
      await FirebaseFirestore.instance.runTransaction((tx) async {
        final like = await tx.get(likeRef);
        final post = await tx.get(postRef);
        if (!post.exists) return;
        final count = (post.data()?['likeCount'] as num?)?.toInt() ?? 0;
        if (like.exists) {
          tx.delete(likeRef);
          tx.update(postRef, {'likeCount': count > 0 ? count - 1 : 0});
        } else {
          tx.set(likeRef, {'userId': uid, 'createdAt': FieldValue.serverTimestamp()});
          tx.update(postRef, {'likeCount': count + 1});
        }
      });
    } catch (_) {
      _toast(tr('Không thể cập nhật lượt thích.','Could not update your like.'));
    }
  }

  Future<void> _openLikes(String postId) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _LikesSheet(
        postId: postId,
        languageCode: widget.languageCode,
      ),
    );
  }

  Future<void> _openComments(String postId) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CommentsSheet(
        postId: postId,
        languageCode: widget.languageCode,
        blocked: _hasBlockedWords,
      ),
    );
  }

  Future<void> _openAuthor(Map<String, dynamic> data) async {
    if (data['isAnonymous'] == true) return;
    // Match Language Exchange: support both userId and legacy uid fields.
    final uid = (data['userId'] ?? data['uid'] ?? '').toString().trim();
    if (uid.isEmpty || uid == me?.uid) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ViewOtherProfilePage(
          userId: uid,
          languageCode: widget.languageCode,
          hideLikeButton: true,
          hidePassButton: true,
          allowActionsForPassedProfile: true,
        ),
      ),
    );
  }

  Future<void> _editPost(String postId, String oldContent) async {
    final controller = TextEditingController(text: oldContent);
    final updated = await showDialog<String>(
      context: context,
      useRootNavigator: true,
      builder: (ctx) => AlertDialog(
        title: Text(tr('Chỉnh sửa bài viết', 'Edit post')),
        content: TextField(
          controller: controller,
          minLines: 3,
          maxLines: 8,
          maxLength: 3000,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx, rootNavigator: true).pop(),
            child: Text(tr('Hủy', 'Cancel')),
          ),
          FilledButton(
            onPressed: () {
              final value = controller.text.trim();
              if (value.isEmpty || _hasBlockedWords(value)) {
                _toast(_hasBlockedWords(value)
                    ? tr('Có từ ngữ không phù hợp.', 'Inappropriate language detected.')
                    : tr('Nội dung không được để trống.', 'Content cannot be empty.'));
                return;
              }
              Navigator.of(ctx, rootNavigator: true).pop(value);
            },
            child: Text(tr('Lưu', 'Save')),
          ),
        ],
      ),
    );
    controller.dispose();
    if (updated == null || updated.isEmpty) return;
    if (_hasBlockedWords(updated)) {
      _toast(tr('Nội dung có từ ngữ không phù hợp.', 'Your post contains language that is not allowed.'));
      return;
    }
    await posts.doc(postId).update({'content': updated, 'updatedAt': FieldValue.serverTimestamp()});
  }

  Future<void> _reportPost(String postId) async {
    final reason = await showDialog<String>(context: context, builder: (ctx) => AlertDialog(
      title: Text(tr('Báo cáo bài viết','Report post')),
      content: Text(tr('Bạn muốn báo cáo nội dung này vì lý do gì?','Why are you reporting this content?')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, 'harassment'), child: Text(tr('Quấy rối / xúc phạm','Harassment / abuse'))),
        TextButton(onPressed: () => Navigator.pop(ctx, 'other'), child: Text(tr('Khác','Other'))),
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tr('Hủy','Cancel'))),
      ],
    ));
    if (reason == null || me == null) return;
    await FirebaseFirestore.instance.collection('community_reports').add({
      'postId': postId, 'reporterId': me!.uid, 'reason': reason,
      'createdAt': FieldValue.serverTimestamp(), 'status': 'open',
    });
    _toast(tr('Cảm ơn bạn đã báo cáo.','Thank you for your report.'));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8FC),
      body: Container(
      color: const Color(0xFFFFF8FC),
      child: Column(children: [
        Expanded(child: CustomScrollView(
          key: const PageStorageKey<String>('community_feed'),
          physics: const ClampingScrollPhysics(),
          slivers: [
          SliverToBoxAdapter(child: _headerAndComposer()),
          SliverToBoxAdapter(child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
            child: Row(children: [
              Text(tr('Community Feed','Community Feed'), style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: _deep)),
              const Spacer(),
              Text(tr('Mới nhất','Latest'), style: const TextStyle(color: _pink, fontWeight: FontWeight.w600)),
            ]),
          )),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: posts.orderBy('createdAt', descending: true).limit(30).snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) return SliverToBoxAdapter(child: _message(tr('Không thể tải bài viết. Kiểm tra Firestore Rules và index.','Could not load posts. Check Firestore Rules and indexes.')));
              if (!snapshot.hasData) return const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.all(28), child: Center(child: CircularProgressIndicator(color: _pink))));
              final docs = snapshot.data!.docs;
              if (docs.isEmpty) return SliverToBoxAdapter(child: _message(tr('Hãy là người đầu tiên chia sẻ câu chuyện nhé. ❤️','Be the first to share your story. ❤️')));
              return SliverList(delegate: SliverChildBuilderDelegate((context, i) {
                final doc = docs[i];
                return _postCard(doc.id, doc.data());
              }, childCount: docs.length));
            },
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ])),
      ]),
      ),
    );
  }

  Widget _headerAndComposer() => Container(
    margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
    padding: const EdgeInsets.fromLTRB(16, 18, 16, 14),
    decoration: BoxDecoration(color: _pale, borderRadius: BorderRadius.circular(22)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text("You're Not Alone ❤️", style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w800, color: _pink)),
      const SizedBox(height: 14),
      Text(tr('Hôm nay của bạn thế nào?','How was your day today?'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: _deep)),
      const SizedBox(height: 12),
      Text(tr(
  "Cuộc sống nơi xứ người đôi khi không dễ dàng. Nếu bạn đang gặp khó khăn, có điều gì trăn trở hay đơn giản chỉ muốn chia sẻ câu chuyện của mình, hãy viết ra tại đây. Những người đã đi trước, có nhiều kinh nghiệm sống ở nước ngoài, có thể chia sẻ lời khuyên và giúp bạn tìm thấy hướng đi. Đôi khi, chỉ một lời tử tế cũng có thể làm ngày của ai đó trở nên tươi sáng hơn. ❤️",
  "Life abroad isn't always easy. If you're facing challenges, have something on your mind, or simply want to share your story, this is a place for you. Those who have walked this journey before you may have valuable experiences and advice to help guide you. Sometimes, just a kind word can brighten someone's day. ❤️",
), style: const TextStyle(fontSize: 16, height: 1.55, color: Color(0xFF75466B))),
      const SizedBox(height: 14),
      Container(
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(17)),
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
        child: Column(children: [
          TextField(
            controller: _composer,
            minLines: 2,
            maxLines: 6,
            maxLength: 3000,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              border: InputBorder.none,
              counterText: '',
              hintText: tr("Chia sẻ điều bạn đang suy nghĩ hôm nay...","Share what's on your mind today..."),
              hintStyle: const TextStyle(color: Colors.grey, fontSize: 16),
              errorText: _hasBlockedWords(_composer.text)
                  ? tr('Vui lòng bỏ từ ngữ không phù hợp.', 'Please remove inappropriate language.')
                  : null,
            ),
          ),
          const Divider(height: 12, color: Color(0xFFEEDDEC)),
          Row(children: [
            PopupMenuButton<String>(
              padding: EdgeInsets.zero,
              onSelected: (v) => setState(() => _feeling = v),
              itemBuilder: (_) => [
                PopupMenuItem(value: '😊 Happy', child: Text(tr('😊 Vui vẻ','😊 Happy'))),
                PopupMenuItem(value: '😔 Sad', child: Text(tr('😔 Buồn','😔 Sad'))),
                PopupMenuItem(value: '😟 Stressed', child: Text(tr('😟 Căng thẳng','😟 Stressed'))),
                PopupMenuItem(value: '🥰 Grateful', child: Text(tr('🥰 Biết ơn','🥰 Grateful'))),
                PopupMenuItem(value: '🤗 Hopeful', child: Text(tr('🤗 Hy vọng','🤗 Hopeful'))),
              ],
              child: Row(children: [const Icon(Icons.favorite_border, color: _pink, size: 19), const SizedBox(width: 5), Text(_feeling == null ? tr('Cảm xúc','Feeling') : _feeling!, style: const TextStyle(color: _pink, fontSize: 13))]),
            ),
            const Spacer(),
            InkWell(onTap: () => setState(() => _anonymous = !_anonymous), child: Row(children: [Icon(_anonymous ? Icons.visibility_off : Icons.person_outline, color: _pink, size: 18), const SizedBox(width: 4), Text(tr('Ẩn danh','Anonymous'), style: const TextStyle(fontSize: 12, color: _pink)), Checkbox(value: _anonymous, onChanged: (v) => setState(() => _anonymous = v ?? false), activeColor: _pink, visualDensity: VisualDensity.compact)])),
            const SizedBox(width: 4),
            FilledButton(onPressed: (_sending || _hasBlockedWords(_composer.text) || _composer.text.trim().isEmpty) ? null : _sendPost, style: FilledButton.styleFrom(backgroundColor: _pink, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 9)), child: _sending ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Text(tr('Gửi','Send'))),
          ]),
        ]),
      ),
    ]),
  );

  Widget _postCard(String id, Map<String, dynamic> d) {
    final anonymous = d['isAnonymous'] == true;
    final name = (d['authorName'] ?? tr('Thành viên VietLove','VietLove member')).toString();
    final photo = (d['authorPhotoUrl'] ?? '').toString();
    final content = (d['content'] ?? '').toString();
    final created = d['createdAt'] is Timestamp ? (d['createdAt'] as Timestamp).toDate() : null;
    final time = created == null ? tr('Vừa xong','Just now') : _timeAgo(created);
    final uid = me?.uid;
    final isMine = uid != null && d['userId'] == uid;
    return Card(margin: const EdgeInsets.fromLTRB(12, 7, 12, 7), elevation: 1, color: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17)), child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: anonymous ? null : () => _openAuthor(d),
          child: CircleAvatar(
            radius: 22,
            backgroundColor: const Color(0xFFF0D9EA),
            backgroundImage: photo.isNotEmpty && !anonymous ? NetworkImage(photo) : null,
            child: photo.isEmpty || anonymous ? const Icon(Icons.person, color: _pink) : null,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(child: InkWell(onTap: anonymous ? null : () => _openAuthor(d), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(name, style: const TextStyle(fontWeight: FontWeight.w800, color: _deep)), Text('$time${(d['feeling'] ?? '').toString().isNotEmpty ? ' · ${d['feeling']}' : ''}', style: const TextStyle(fontSize: 12, color: Colors.grey))]))),
        PopupMenuButton<String>(onSelected: (v) async { if (v == 'report') await _reportPost(id); if (v == 'edit' && isMine) await _editPost(id, content); if (v == 'delete' && isMine) await posts.doc(id).delete(); }, itemBuilder: (_) => [if (!isMine) PopupMenuItem(value: 'report', child: Text(tr('Báo cáo','Report'))), if (isMine) PopupMenuItem(value: 'edit', child: Text(tr('Chỉnh sửa','Edit'))), if (isMine) PopupMenuItem(value: 'delete', child: Text(tr('Xóa bài viết','Delete post')))]),
      ]),
      const SizedBox(height: 12),
      Text(content, style: const TextStyle(fontSize: 15.5, height: 1.5, color: Color(0xFF333333))),
      const SizedBox(height: 12),
      Row(children: [
        InkWell(
          onTap: () => _openLikes(id),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
            child: Text('❤️ ${d['likeCount'] ?? 0}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ),
        ),
        const Spacer(),
        InkWell(
          onTap: () => _openComments(id),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
            child: Text('${d['commentCount'] ?? 0} ${tr('bình luận','comments')}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ),
        ),
      ]),
      const Divider(height: 18),
      Row(children: [
        Expanded(child: InkWell(onTap: () => _toggleLike(id), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.favorite_border, color: _pink, size: 19), const SizedBox(width: 6), Text(tr('Thích','Like'), style: const TextStyle(color: _deep))]))),
        Expanded(child: InkWell(onTap: () => _openComments(id), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.chat_bubble_outline, color: _pink, size: 19), const SizedBox(width: 6), Text(tr('Bình luận','Comment'), style: const TextStyle(color: _deep))]))),
      ]),
    ])));
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return tr('Vừa xong','Just now');
    if (diff.inHours < 1) return tr('${diff.inMinutes} phút trước','${diff.inMinutes} min ago');
    if (diff.inDays < 1) return tr('${diff.inHours} giờ trước','${diff.inHours} hr ago');
    return tr('${diff.inDays} ngày trước','${diff.inDays} days ago');
  }

  Widget _message(String text) => Padding(padding: const EdgeInsets.all(28), child: Center(child: Text(text, textAlign: TextAlign.center, style: const TextStyle(color: _deep))));
}

class _CommentsSheet extends StatefulWidget {
  final String postId;
  final String languageCode;
  final bool Function(String) blocked;
  const _CommentsSheet({required this.postId, required this.languageCode, required this.blocked});
  @override
  State<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<_CommentsSheet> {
  final _text = TextEditingController();
  bool _sending = false;
  String? _replyToId;
  String? _replyToName;
  String? _editingCommentId;
  final TextEditingController _editController = TextEditingController();
  bool _savingCommentEdit = false;
  bool get isVi => widget.languageCode == 'vi';
  String tr(String vi, String en) => isVi ? vi : en;
  User? get me => FirebaseAuth.instance.currentUser;
  CollectionReference<Map<String, dynamic>> get comments => FirebaseFirestore.instance.collection('community_comments');

  Future<void> _openCommentAuthor(String uid) async {
    if (uid.trim().isEmpty || uid.trim() == me?.uid) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ViewOtherProfilePage(
          userId: uid.trim(),
          languageCode: widget.languageCode,
          hideLikeButton: true,
          hidePassButton: true,
          allowActionsForPassedProfile: true,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _text.dispose();
    _editController.dispose();
    super.dispose();
  }

  Future<void> _editComment(String commentId, String oldContent) async {
    final uid = me?.uid;
    if (uid == null || _savingCommentEdit) return;
    try {
      final ref = comments.doc(commentId);
      final snapshot = await ref.get();
      final ownerId = (snapshot.data()?['userId'] ?? snapshot.data()?['uid'] ?? '').toString().trim();
      if (!mounted) return;
      if (!snapshot.exists || ownerId != uid) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('Bạn chỉ có thể sửa bình luận của mình.', 'You can only edit your own comments.'))),
        );
        return;
      }
      setState(() {
        _editingCommentId = commentId;
        _editController.text = oldContent;
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('Không thể mở phần sửa bình luận.', 'Could not open comment editor.'))),
      );
    }
  }

  void _cancelCommentEdit() {
    if (_savingCommentEdit) return;
    setState(() {
      _editingCommentId = null;
      _editController.clear();
    });
  }

  Future<void> _saveCommentEdit(String commentId) async {
    final uid = me?.uid;
    final value = _editController.text.trim();
    if (uid == null || _savingCommentEdit) return;
    if (value.isEmpty || value.length > 1000 || widget.blocked(value)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.blocked(value)
            ? tr('Có từ ngữ không phù hợp.', 'Inappropriate language detected.')
            : tr('Bình luận không được để trống.', 'Comment cannot be empty.'))),
      );
      return;
    }

    setState(() => _savingCommentEdit = true);
    try {
      final ref = comments.doc(commentId);
      final latest = await ref.get();
      final ownerId = (latest.data()?['userId'] ?? latest.data()?['uid'] ?? '').toString().trim();
      if (!latest.exists || ownerId != uid) {
        throw StateError('Comment owner mismatch');
      }
      await ref.update({
        'content': value,
        'editedAt': FieldValue.serverTimestamp(),
      });
      if (!mounted) return;
      setState(() {
        _editingCommentId = null;
        _editController.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('Đã cập nhật bình luận.', 'Comment updated.'))),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('Không thể sửa bình luận. Vui lòng thử lại.', 'Could not edit comment. Please try again.'))),
      );
    } finally {
      if (mounted) setState(() => _savingCommentEdit = false);
    }
  }


  Future<void> _deleteComment(String commentId) async {
    final uid = me?.uid;
    if (uid == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('Xóa bình luận?', 'Delete comment?')),
        content: Text(tr(
          'Bạn có chắc muốn xóa bình luận này không?',
          'Are you sure you want to delete this comment?',
        )),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(tr('Hủy', 'Cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(tr('Xóa', 'Delete')),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      final ref = comments.doc(commentId);
      final latest = await ref.get();
      final ownerId =
          (latest.data()?['userId'] ?? latest.data()?['uid'] ?? '')
              .toString()
              .trim();

      if (!latest.exists || ownerId != uid) {
        throw StateError('Comment owner mismatch');
      }

      // Delete only the comment written by the current user. Replies from
      // other members are preserved.
      final batch = FirebaseFirestore.instance.batch();
      batch.delete(ref);
      batch.update(
        FirebaseFirestore.instance
            .collection('community_posts')
            .doc(widget.postId),
        {'commentCount': FieldValue.increment(-1)},
      );
      await batch.commit();

      if (!mounted) return;
      if (_editingCommentId == commentId) {
        setState(() {
          _editingCommentId = null;
          _editController.clear();
        });
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('Đã xóa bình luận.', 'Comment deleted.'))),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr(
          'Không thể xóa bình luận. Vui lòng thử lại.',
          'Could not delete comment. Please try again.',
        ))),
      );
    }
  }

  Future<void> _send() async {
    final value = _text.text.trim();
    if (value.isEmpty || me == null || _sending) return;
    if (widget.blocked(value)) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('Bình luận có từ ngữ không phù hợp.','Your comment contains language that is not allowed.'))));
      return;
    }
    setState(() => _sending = true);
    try {
      final user = await FirebaseFirestore.instance.collection('users').doc(me!.uid).get();
      final data = user.data() ?? {};
      await comments.add({'postId': widget.postId, 'userId': me!.uid, 'authorName': (data['firstName'] ?? me!.displayName ?? tr('Thành viên','Member')).toString(), 'authorPhotoUrl': (data['mainPhotoUrl'] ?? data['photoUrl'] ?? me!.photoURL ?? '').toString(), 'content': value, 'parentCommentId': _replyToId, 'createdAt': FieldValue.serverTimestamp()});
      await FirebaseFirestore.instance.collection('community_posts').doc(widget.postId).update({'commentCount': FieldValue.increment(1)});
      _text.clear();
      setState(() { _replyToId = null; _replyToName = null; });
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('Không thể gửi bình luận.','Could not send comment.'))));
    } finally { if (mounted) setState(() => _sending = false); }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * .86,
        child: Material(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
          clipBehavior: Clip.antiAlias,
          child: SafeArea(
            top: false,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
                  child: Row(
                    children: [
                      Text(tr('Bình luận', 'Comments'), style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: Color(0xFF603B59))),
                      const Spacer(),
                      IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    // Avoid requiring a composite index for postId + createdAt.
                    stream: comments.where('postId', isEqualTo: widget.postId).limit(100).snapshots(),
                    builder: (context, snap) {
                      if (snap.hasError) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              tr('Không thể tải bình luận. Vui lòng kiểm tra quyền đọc collection community_comments trong Firestore Rules.',
                                 'Could not load comments. Please check read permissions for community_comments in Firestore Rules.'),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        );
                      }
                      if (!snap.hasData) return const Center(child: CircularProgressIndicator(color: Color(0xFFC04491)));
                      final docs = [...snap.data!.docs];
                      docs.sort((a, b) {
                        final at = a.data()['createdAt'];
                        final bt = b.data()['createdAt'];
                        final ad = at is Timestamp ? at : Timestamp(0, 0);
                        final bd = bt is Timestamp ? bt : Timestamp(0, 0);
                        return ad.compareTo(bd);
                      });
                      if (docs.isEmpty) {
                        return Center(child: Text(tr('Hãy là người đầu tiên bình luận.', 'Be the first to comment.')));
                      }
                      return ListView.builder(
                        key: const PageStorageKey<String>('community_comments'),
                        physics: const ClampingScrollPhysics(),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: docs.length,
                        itemBuilder: (context, i) {
                          final doc = docs[i];
                          final d = doc.data();
                          final photo = (d['authorPhotoUrl'] ?? '').toString();
                          final parentId = (d['parentCommentId'] ?? '').toString();
                          final isReply = parentId.isNotEmpty;
                          return Padding(
                            padding: EdgeInsets.only(left: isReply ? 38 : 8, right: 8, top: 3, bottom: 3),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () => _openCommentAuthor((d['userId'] ?? d['uid'] ?? '').toString().trim()),
                                  child: CircleAvatar(
                                    radius: 18,
                                    backgroundColor: const Color(0xFFF5E9F5),
                                    backgroundImage: photo.isEmpty ? null : NetworkImage(photo),
                                    child: photo.isEmpty ? const Icon(Icons.person, size: 18, color: Color(0xFFC04491)) : null,
                                  ),
                                ),
                                const SizedBox(width: 9),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                                        decoration: BoxDecoration(color: const Color(0xFFF6F1F5), borderRadius: BorderRadius.circular(15)),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            InkWell(
                                              onTap: () => _openCommentAuthor(
                                     (d['userId'] ?? d['uid'] ?? '').toString().trim(),
                                   ),
                                              child: Text(
                                                (d['authorName'] ?? tr('Thành viên', 'Member')).toString(),
                                                style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF603B59)),
                                              ),
                                            ),
                                            const SizedBox(height: 3),
                                            if (_editingCommentId == doc.id) ...[
                                              TextField(
                                                controller: _editController,
                                                autofocus: true,
                                                minLines: 2,
                                                maxLines: 5,
                                                maxLength: 1000,
                                                decoration: InputDecoration(
                                                  hintText: tr('Nhập bình luận mới...', 'Update your comment...'),
                                                  isDense: true,
                                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                                ),
                                              ),
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.end,
                                                children: [
                                                  TextButton(
                                                    onPressed: _savingCommentEdit ? null : _cancelCommentEdit,
                                                    child: Text(tr('Hủy', 'Cancel')),
                                                  ),
                                                  const SizedBox(width: 6),
                                                  FilledButton(
                                                    onPressed: _savingCommentEdit ? null : () => _saveCommentEdit(doc.id),
                                                    child: _savingCommentEdit
                                                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                                                        : Text(tr('Lưu', 'Save')),
                                                  ),
                                                ],
                                              ),
                                            ] else
                                              Text((d['content'] ?? '').toString()),
                                          ],
                                        ),
                                      ),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          TextButton(
                                            onPressed: () => setState(() {
                                              _replyToId = isReply ? parentId : doc.id;
                                              _replyToName = (d['authorName'] ?? tr('Thành viên', 'Member')).toString();
                                            }),
                                            style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                                            child: Text(tr('Trả lời', 'Reply'), style: const TextStyle(color: Color(0xFFC04491), fontSize: 12)),
                                          ),
                                          if (me != null && (d['userId'] ?? d['uid'] ?? '').toString().trim() == me!.uid && _editingCommentId != doc.id) ...[
                                            TextButton.icon(
                                              onPressed: () => _editComment(doc.id, (d['content'] ?? '').toString()),
                                              style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                                              icon: const Icon(Icons.edit_outlined, size: 13, color: Color(0xFFC04491)),
                                              label: Text(tr('Sửa', 'Edit'), style: const TextStyle(color: Color(0xFFC04491), fontSize: 12)),
                                            ),
                                            TextButton.icon(
                                              onPressed: () => _deleteComment(doc.id),
                                              style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                                              icon: const Icon(Icons.delete_outline, size: 13, color: Colors.red),
                                              label: Text(tr('Xóa', 'Delete'), style: const TextStyle(color: Colors.red, fontSize: 12)),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_replyToId != null)
                        Row(
                          children: [
                            Expanded(child: Text(tr('Đang trả lời $_replyToName', 'Replying to $_replyToName'), style: const TextStyle(color: Color(0xFFC04491), fontSize: 12))),
                            IconButton(onPressed: () => setState(() { _replyToId = null; _replyToName = null; }), icon: const Icon(Icons.close, size: 18)),
                          ],
                        ),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _text,
                              minLines: 1,
                              maxLines: 3,
                              onChanged: (_) => setState(() {}),
                              decoration: InputDecoration(
                                hintText: tr('Viết bình luận...', 'Write a comment...'),
                                errorText: widget.blocked(_text.text) ? tr('Từ ngữ không phù hợp.', 'Inappropriate language.') : null,
                                filled: true,
                                fillColor: const Color(0xFFF7F2F6),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: BorderSide.none),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            onPressed: (_sending || _text.text.trim().isEmpty || widget.blocked(_text.text)) ? null : _send,
                            icon: const Icon(Icons.send_rounded, color: Color(0xFFC04491)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LikesSheet extends StatelessWidget {
  final String postId;
  final String languageCode;
  const _LikesSheet({required this.postId, required this.languageCode});

  bool get isVi => languageCode == 'vi';
  String tr(String vi, String en) => isVi ? vi : en;

  Future<void> _openLikedUser(BuildContext context, String uid) async {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (uid.isEmpty || uid == currentUid) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ViewOtherProfilePage(
          userId: uid,
          languageCode: languageCode,
          hideLikeButton: true,
          hidePassButton: true,
          allowActionsForPassedProfile: true,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final likes = FirebaseFirestore.instance
        .collection('community_posts')
        .doc(postId)
        .collection('likes');
    return SizedBox(
      height: MediaQuery.of(context).size.height * .65,
      child: Material(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        clipBehavior: Clip.antiAlias,
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
                child: Row(
                  children: [
                    Text(tr('Những người đã thích', 'People who liked this'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF603B59))),
                    const Spacer(),
                    IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: likes.orderBy('createdAt', descending: true).snapshots(),
                  builder: (context, snap) {
                    if (snap.hasError) return Center(child: Text(tr('Không thể tải danh sách lượt thích. Kiểm tra Firestore Rules.', 'Could not load likes. Check Firestore Rules.')));
                    if (!snap.hasData) return const Center(child: CircularProgressIndicator(color: Color(0xFFC04491)));
                    final docs = snap.data!.docs;
                    if (docs.isEmpty) return Center(child: Text(tr('Chưa có ai thích bài viết này.', 'No likes yet.')));
                    return ListView.builder(
                      key: const PageStorageKey<String>('community_likes'),
                      physics: const ClampingScrollPhysics(),
                      itemCount: docs.length,
                      itemBuilder: (context, index) {
                        final likeData = docs[index].data();
                        final storedUserId = (likeData['userId'] ?? '').toString().trim();
                        final uid = storedUserId.isNotEmpty ? storedUserId : docs[index].id.trim();
                        return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                          future: FirebaseFirestore.instance.collection('users').doc(uid).get(),
                          builder: (context, userSnap) {
                            final data = userSnap.data?.data() ?? {};
                            final name = (data['firstName'] ?? data['displayName'] ?? tr('Thành viên VietLove', 'VietLove member')).toString();
                            final photo = (data['mainPhotoUrl'] ?? data['photoUrl'] ?? '').toString();
                            return ListTile(
                              onTap: () => _openLikedUser(context, uid),
                              leading: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () => _openLikedUser(context, uid),
                                child: CircleAvatar(
                                  radius: 22,
                                  backgroundColor: const Color(0xFFF5E9F5),
                                  backgroundImage: photo.startsWith('http') ? NetworkImage(photo) : null,
                                  child: photo.isEmpty || !photo.startsWith('http') ? const Icon(Icons.person, color: Color(0xFFC04491)) : null,
                                ),
                              ),
                              title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
                              trailing: const Icon(Icons.favorite, color: Color(0xFFE85D8F), size: 19),
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

