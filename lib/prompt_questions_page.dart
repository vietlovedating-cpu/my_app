import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'home_page.dart';
import 'prompt_data.dart';

class PromptQuestionsPage extends StatefulWidget {
  final String languageCode;
  final List<Map<String, dynamic>>? initialAnswers;

  const PromptQuestionsPage({
    super.key,
    required this.languageCode,
    this.initialAnswers,
  });

  @override
  State<PromptQuestionsPage> createState() => _PromptQuestionsPageState();
}

class _PromptQuestionsPageState extends State<PromptQuestionsPage> {
  bool isSaving = false;

  late final List<_PromptCategoryGroup> groups;

  bool get isVi => widget.languageCode == 'vi';

  @override
  void initState() {
    super.initState();

    groups = [
      _PromptCategoryGroup(
        categoryKey: 'love',
        categoryVi: 'Tình yêu',
        categoryEn: 'Love',
        options: kPromptOptions
            .where((e) => e.categoryVi == 'Tình yêu')
            .toList(),
      ),
      _PromptCategoryGroup(
        categoryKey: 'personality',
        categoryVi: 'Tính cách',
        categoryEn: 'Personality',
        options: kPromptOptions
            .where((e) => e.categoryVi == 'Tính cách')
            .toList(),
      ),
      _PromptCategoryGroup(
        categoryKey: 'lifestyle',
        categoryVi: 'Lối sống',
        categoryEn: 'Lifestyle',
        options: kPromptOptions
            .where((e) => e.categoryVi == 'Lối sống')
            .toList(),
      ),
      _PromptCategoryGroup(
        categoryKey: 'family',
        categoryVi: 'Gia đình',
        categoryEn: 'Family',
        options: kPromptOptions
            .where((e) => e.categoryVi == 'Gia đình')
            .toList(),
      ),
      _PromptCategoryGroup(
        categoryKey: 'future',
        categoryVi: 'Tương lai',
        categoryEn: 'Future',
        options: kPromptOptions
            .where((e) => e.categoryVi == 'Tương lai')
            .toList(),
      ),
    ];

    if (widget.initialAnswers != null) {
      for (final answer in widget.initialAnswers!) {
        final categoryKey = answer['categoryKey']?.toString() ?? '';
        final promptId = answer['promptId']?.toString() ?? '';

        final group =
            groups.where((g) => g.categoryKey == categoryKey).firstOrNull;

        if (group != null) {
          final option = group.options.where((o) => o.id == promptId).firstOrNull;

          if (option != null) {
            group.selectedOption = option;

            final savedAnswerIndex = _readAnswerIndex(answer['answerIndex']);
            group.selectedAnswerIndex = savedAnswerIndex;

            if (savedAnswerIndex != null &&
                savedAnswerIndex >= 0 &&
                savedAnswerIndex < option.aiSuggestionsVi.length &&
                savedAnswerIndex < option.aiSuggestionsEn.length) {
              group.controller.text = isVi
                  ? option.aiSuggestionsVi[savedAnswerIndex]
                  : option.aiSuggestionsEn[savedAnswerIndex];
            } else {
              final response = isVi
                  ? ((answer['answerVi'] ?? answer['answer'] ?? '')
                      .toString()
                      .trim())
                  : ((answer['answerEn'] ?? answer['answer'] ?? '')
                      .toString()
                      .trim());

              group.controller.text = response;
            }
          }
        }
      }
    }
  }

  int? _readAnswerIndex(dynamic value) {
    if (value is int) return value;
    return int.tryParse((value ?? '').toString().trim());
  }

  Future<void> _useAiSuggestion(_PromptCategoryGroup group) async {
    final option = group.selectedOption;
    if (option == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isVi ? 'Hãy chọn một câu hỏi trước' : 'Please choose a question first',
          ),
        ),
      );
      return;
    }

    final suggestions = isVi ? option.aiSuggestionsVi : option.aiSuggestionsEn;

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Icon(Icons.auto_awesome, color: Colors.pink),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        isVi ? 'AI gợi ý' : 'AI Suggestions',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                ...List.generate(suggestions.length, (index) {
                  final text = suggestions[index];

                  return Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 10),
                    child: OutlinedButton(
                      onPressed: () {
                        setState(() {
                          group.controller.text = text;
                          group.selectedAnswerIndex = index;
                          group.lastFilledByAi = true;
                        });
                        Navigator.pop(context);
                      },
                      style: OutlinedButton.styleFrom(
                        alignment: Alignment.centerLeft,
                        padding: const EdgeInsets.all(14),
                        foregroundColor: Colors.black87,
                        side: BorderSide(color: Colors.pink.withOpacity(0.35)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        text,
                        style: const TextStyle(
                          fontSize: 14.5,
                          height: 1.4,
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _savePrompts() async {
    if (isSaving) return;

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isVi ? 'Không tìm thấy người dùng' : 'User not found'),
        ),
      );
      return;
    }

    final answers = <Map<String, dynamic>>[];

    for (final group in groups) {
      if (group.selectedOption != null && group.controller.text.trim().isNotEmpty) {
        final option = group.selectedOption!;
        final answerText = group.controller.text.trim();
        final answerIndex = group.selectedAnswerIndex;

        String answerVi = '';
        String answerEn = '';

        final bool canUseAiIndex = answerIndex != null &&
            answerIndex >= 0 &&
            answerIndex < option.aiSuggestionsVi.length &&
            answerIndex < option.aiSuggestionsEn.length;

        if (canUseAiIndex) {
          answerVi = option.aiSuggestionsVi[answerIndex];
          answerEn = option.aiSuggestionsEn[answerIndex];
        } else {
          if (isVi) {
            answerVi = answerText;
            answerEn = '';
          } else {
            answerEn = answerText;
            answerVi = '';
          }
        }

        answers.add({
          'categoryKey': group.categoryKey,
          'categoryVi': group.categoryVi,
          'categoryEn': group.categoryEn,
          'promptId': option.id,
          'questionVi': option.questionVi,
          'questionEn': option.questionEn,
          'answerIndex': canUseAiIndex ? answerIndex : null,
          'answer': answerText,
          'answerVi': answerVi,
          'answerEn': answerEn,
        });
      }
    }

    if (answers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isVi ? 'Hãy điền ít nhất 1 prompt' : 'Please complete at least 1 prompt',
          ),
        ),
      );
      return;
    }

    setState(() {
      isSaving = true;
    });

    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'profilePrompts': answers,
        'profilePromptsCompleted': true,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => HomePage(languageCode: widget.languageCode),
        ),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isVi ? 'Lỗi khi lưu prompt: $e' : 'Error saving prompts: $e',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          isSaving = false;
        });
      }
    }
  }

  @override
  void dispose() {
    for (final group in groups) {
      group.controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8DCE5),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8DCE5),
        elevation: 0,
        centerTitle: true,
        title: Text(
          isVi ? 'Giới thiệu bản thân' : 'Profile Prompts',
          style: const TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w800,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
                itemCount: groups.length,
                itemBuilder: (_, index) {
                  final group = groups[index];
                  return _PromptGroupCard(
                    group: group,
                    languageCode: widget.languageCode,
                    onAiTap: () => _useAiSuggestion(group),
                    onChangedOption: (option) {
                      setState(() {
                        group.selectedOption = option;
                        group.selectedAnswerIndex = null;
                        group.lastFilledByAi = false;
                        group.controller.clear();
                      });
                    },
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
              child: SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: isSaving ? null : _savePrompts,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.pink,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: isSaving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.3,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          isVi ? 'Lưu prompt' : 'Save prompts',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PromptGroupCard extends StatelessWidget {
  final _PromptCategoryGroup group;
  final String languageCode;
  final VoidCallback onAiTap;
  final ValueChanged<PromptOption> onChangedOption;

  const _PromptGroupCard({
    required this.group,
    required this.languageCode,
    required this.onAiTap,
    required this.onChangedOption,
  });

  @override
  Widget build(BuildContext context) {
    final isVi = languageCode == 'vi';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.96),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isVi ? group.categoryVi : group.categoryEn,
            style: const TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w800,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<PromptOption>(
            value: group.selectedOption,
            isExpanded: true,
            decoration: InputDecoration(
              filled: true,
              fillColor: const Color(0xFFFDF5F8),
              hintText: isVi ? 'Chọn 1 câu hỏi' : 'Choose one question',
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Colors.pink.withOpacity(0.2)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Colors.pink.withOpacity(0.2)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Colors.pink, width: 1.4),
              ),
            ),
            selectedItemBuilder: (context) {
              return group.options.map((option) {
                return Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    isVi ? option.questionVi : option.questionEn,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList();
            },
            items: group.options.map((option) {
              return DropdownMenuItem<PromptOption>(
                value: option,
                child: SizedBox(
                  width: double.infinity,
                  child: Text(
                    isVi ? option.questionVi : option.questionEn,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              );
            }).toList(),
            onChanged: (value) {
              if (value != null) onChangedOption(value);
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: group.controller,
            minLines: 4,
            maxLines: 6,
            onChanged: (_) {
              if (group.lastFilledByAi) {
                group.selectedAnswerIndex = null;
                group.lastFilledByAi = false;
              }
            },
            decoration: InputDecoration(
              hintText:
                  isVi ? 'Viết câu trả lời của bạn...' : 'Write your answer...',
              filled: true,
              fillColor: const Color(0xFFFDF5F8),
              contentPadding: const EdgeInsets.all(14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Colors.pink.withOpacity(0.2)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Colors.pink.withOpacity(0.2)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Colors.pink, width: 1.4),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Flexible(
                child: OutlinedButton.icon(
                  onPressed: onAiTap,
                  icon: const Icon(Icons.auto_awesome, size: 18),
                  label: Text(
                    isVi ? 'AI hỗ trợ' : 'AI help',
                    overflow: TextOverflow.ellipsis,
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.pink,
                    side: const BorderSide(color: Colors.pink),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PromptCategoryGroup {
  final String categoryKey;
  final String categoryVi;
  final String categoryEn;
  final List<PromptOption> options;
  final TextEditingController controller = TextEditingController();

  PromptOption? selectedOption;
  int? selectedAnswerIndex;
  bool lastFilledByAi;

  _PromptCategoryGroup({
    required this.categoryKey,
    required this.categoryVi,
    required this.categoryEn,
    required this.options,
    this.lastFilledByAi = false,
  });
}

extension _IterableExt<E> on Iterable<E> {
  E? get firstOrNull => isEmpty ? null : first;
}