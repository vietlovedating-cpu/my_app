import 'package:flutter/material.dart';
import 'current_location_page.dart';

class StateQuestionPage extends StatefulWidget {
  final String languageCode;
  final String firstName;

  const StateQuestionPage({
    super.key,
    required this.languageCode,
    required this.firstName,
  });

  @override
  State<StateQuestionPage> createState() => _StateQuestionPageState();
}

class _StateQuestionPageState extends State<StateQuestionPage> {
  String? selectedState;

  final List<String> states = const [
    'New South Wales (NSW)',
    'Victoria (VIC)',
    'Queensland (QLD)',
    'South Australia (SA)',
    'Western Australia (WA)',
    'Tasmania (TAS)',
  ];

  @override
  Widget build(BuildContext context) {
    final isVi = widget.languageCode == 'vi';
    final bool isEnabled = selectedState != null;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFFFFF0F5),
              Color(0xFFFFFFFF),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      icon: const Icon(Icons.arrow_back_ios_new_rounded),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      const SizedBox(height: 10),
                      Container(
                        width: 88,
                        height: 88,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFFFF5C93).withOpacity(0.10),
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.favorite,
                            size: 42,
                            color: Color(0xFFE91E63),
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),
                      Text(
                        isVi
                            ? 'Bạn sống ở bang nào?'
                            : 'Which state do you live in?',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF222222),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        isVi
                            ? 'Chọn bang nơi bạn đang sinh sống để Viet Love có thể gợi ý phù hợp hơn cho bạn.'
                            : 'Select the state you currently live in so Viet Love can suggest better matches for you.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 15,
                          height: 1.6,
                          color: Color(0xFF555555),
                        ),
                      ),
                      const SizedBox(height: 28),
                      DropdownButtonFormField<String>(
                        value: selectedState,
                        isExpanded: true,
                        hint: Text(
                          isVi ? 'Chọn bang của bạn' : 'Select your state',
                        ),
                        items: states.map((state) {
                          return DropdownMenuItem<String>(
                            value: state,
                            child: Text(
                              state,
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            selectedState = value;
                          });
                        },
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 18,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: const BorderSide(
                              color: Color(0xFFFFD6E7),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: const BorderSide(
                              color: Color(0xFFE91E63),
                              width: 1.5,
                            ),
                          ),
                        ),
                        icon: const Icon(Icons.keyboard_arrow_down_rounded),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.favorite, color: Color(0xFFFF8FB1), size: 16),
                          SizedBox(width: 8),
                          Icon(Icons.favorite, color: Color(0xFFFF5C93), size: 20),
                          SizedBox(width: 8),
                          Icon(Icons.favorite, color: Color(0xFFFF8FB1), size: 16),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: isEnabled
                        ? () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => CurrentLocationPage(
                                  languageCode: widget.languageCode,
                                  selectedState: selectedState!,
                                  firstName: widget.firstName,
                                ),
                              ),
                            );
                          }
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE91E63),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: const Color(0xFFF3C7D6),
                      disabledForegroundColor: Colors.white70,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: Text(
                      isVi ? 'Tiếp tục' : 'Continue',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}