import 'package:flutter/material.dart';

import '../../data/ai_dashboard_service.dart';

class AiDashboardCard extends StatefulWidget {

  final int userId;

  final int companyId;

  final DateTime from;

  final DateTime to;

  const AiDashboardCard({

    super.key,

    required this.userId,

    required this.companyId,

    required this.from,

    required this.to,

  });

  @override
  State<AiDashboardCard> createState() =>
      _AiDashboardCardState();
}

class _AiDashboardCardState
    extends State<AiDashboardCard> {

  final TextEditingController controller =
      TextEditingController();

  bool loading = false;

  String answer = '';

  // ------------------------------------------------------------
  // ASK AI
  // ------------------------------------------------------------

  Future<void> askAI() async {

    final question =
        controller.text.trim();

    if (question.isEmpty) {

      ScaffoldMessenger.of(context)
          .showSnackBar(

        const SnackBar(
          content: Text(
            'Enter your question',
          ),
        ),

      );

      return;
    }

    setState(() {

      loading = true;

      answer = '';

    });

    try {

      final result =
          await AiDashboardService.ask(

        userId: widget.userId,

        companyId: widget.companyId,

        fromDate:
            _date(widget.from),

        toDate:
            _date(widget.to),

        question: question,

      );

      if (!mounted) return;

      setState(() {

        answer = result;

        loading = false;

      });

    }
    catch (e) {

      if (!mounted) return;

      setState(() {

        loading = false;

        answer =
            'Unable to get AI response.\n$e';

      });

    }

  }

  String _date(DateTime date) {

    return '${date.year}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';

  }

  @override
  void dispose() {

    controller.dispose();

    super.dispose();

  }

  @override
  Widget build(BuildContext context) {

    return Container(

      padding:
          const EdgeInsets.all(16),

      decoration: BoxDecoration(

        gradient: const LinearGradient(

          begin: Alignment.topLeft,

          end: Alignment.bottomRight,

          colors: [

            Color(0xFFF0EEFF),

            Color(0xFFFFFFFF),

          ],

        ),

        borderRadius:
            BorderRadius.circular(22),

        border: Border.all(

          color:
              const Color(0xFFE1DDFB),

        ),

      ),

      child: Column(

        crossAxisAlignment:
            CrossAxisAlignment.start,

        children: [

          // ----------------------------------------------------
          // HEADER
          // ----------------------------------------------------

          Row(

            children: [

              Container(

                width: 44,

                height: 44,

                decoration: BoxDecoration(

                  color:
                      const Color(0xFF2300C4),

                  borderRadius:
                      BorderRadius.circular(14),

                ),

                child: const Icon(

                  Icons.auto_awesome,

                  color: Colors.white,

                ),

              ),

              const SizedBox(width: 12),

              const Expanded(

                child: Column(

                  crossAxisAlignment:
                      CrossAxisAlignment.start,

                  children: [

                    Text(

                      'AI Business Assistant',

                      style: TextStyle(

                        fontSize: 16,

                        fontWeight:
                            FontWeight.w900,

                      ),

                    ),

                    SizedBox(height: 3),

                    Text(

                      'Ask about your dashboard',

                      style: TextStyle(

                        fontSize: 11,

                        color:
                            Color(0xFF737781),

                      ),

                    ),

                  ],

                ),

              ),

            ],

          ),

          const SizedBox(height: 15),

          // ----------------------------------------------------
          // QUICK QUESTIONS
          // ----------------------------------------------------

          Wrap(

            spacing: 7,

            runSpacing: 7,

            children: [

              _quickQuestion(
                'Why am I below target?',
              ),

              _quickQuestion(
                'Best salesman?',
              ),

              _quickQuestion(
                'Who needs attention?',
              ),

              _quickQuestion(
                'Outstanding customers?',
              ),

            ],

          ),

          const SizedBox(height: 12),

          // ----------------------------------------------------
          // QUESTION
          // ----------------------------------------------------

          TextField(

            controller:
                controller,

            minLines: 1,

            maxLines: 4,

            decoration:
                InputDecoration(

              hintText:
                  'Ask something about sales...',

              filled: true,

              fillColor:
                  Colors.white,

              border:
                  OutlineInputBorder(

                borderRadius:
                    BorderRadius.circular(14),

                borderSide:
                    BorderSide.none,

              ),

              contentPadding:
                  const EdgeInsets.symmetric(

                horizontal: 14,

                vertical: 13,

              ),

            ),

          ),

          const SizedBox(height: 10),

          // ----------------------------------------------------
          // ASK BUTTON
          // ----------------------------------------------------

          SizedBox(

            width: double.infinity,

            child: ElevatedButton.icon(

              onPressed:
                  loading ? null : askAI,

              icon: loading

                  ? const SizedBox(

                      width: 17,

                      height: 17,

                      child:
                          CircularProgressIndicator(

                        strokeWidth: 2,

                        color: Colors.white,

                      ),

                    )

                  : const Icon(
                      Icons.auto_awesome,
                    ),

              label: Text(

                loading
                    ? 'Analyzing...'
                    : 'Ask AI',

              ),

              style:
                  ElevatedButton.styleFrom(

                backgroundColor:
                    const Color(0xFF2300C4),

                foregroundColor:
                    Colors.white,

                minimumSize:
                    const Size(

                  double.infinity,

                  48,

                ),

                shape:
                    RoundedRectangleBorder(

                  borderRadius:
                      BorderRadius.circular(14),

                ),

              ),

            ),

          ),

          // ----------------------------------------------------
          // ANSWER
          // ----------------------------------------------------

          if (answer.isNotEmpty) ...[

            const SizedBox(height: 14),

            Container(

              width: double.infinity,

              padding:
                  const EdgeInsets.all(14),

              decoration: BoxDecoration(

                color:
                    Colors.white,

                borderRadius:
                    BorderRadius.circular(15),

              ),

              child: Row(

                crossAxisAlignment:
                    CrossAxisAlignment.start,

                children: [

                  const Icon(

                    Icons.lightbulb_outline,

                    color:
                        Color(0xFF2300C4),

                    size: 21,

                  ),

                  const SizedBox(width: 10),

                  Expanded(

                    child: Text(

                      answer,

                      style:
                          const TextStyle(

                        fontSize: 12,

                        height: 1.5,

                        fontWeight:
                            FontWeight.w600,

                      ),

                    ),

                  ),

                ],

              ),

            ),

          ],

        ],

      ),

    );

  }

  Widget _quickQuestion(
      String question) {

    return InkWell(

      onTap: () {

        controller.text =
            question;

        askAI();

      },

      borderRadius:
          BorderRadius.circular(20),

      child: Container(

        padding:
            const EdgeInsets.symmetric(

          horizontal: 10,

          vertical: 7,

        ),

        decoration: BoxDecoration(

          color:
              Colors.white,

          borderRadius:
              BorderRadius.circular(20),

          border: Border.all(

            color:
                const Color(0xFFE4E7EF),

          ),

        ),

        child: Text(

          question,

          style:
              const TextStyle(

            fontSize: 10,

            fontWeight:
                FontWeight.w700,

          ),

        ),

      ),

    );

  }
}