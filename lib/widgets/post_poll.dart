import 'package:flutter/material.dart';
import '../config/api_config.dart';
import '../models/post.dart';

class PostPoll extends StatelessWidget {
  const PostPoll({
    required this.post,
    required this.isBusy,
    required this.onVote,
    super.key,
  });

  final Post post;
  final bool isBusy;
  final ValueChanged<int> onVote;

  @override
  Widget build(BuildContext context) {
    final options = post.pollOptions;
    if (options.length < 2) {
      return const SizedBox.shrink();
    }

    final votes = [
      for (var index = 0; index < options.length; index++)
        index < post.pollOptionVotes.length ? post.pollOptionVotes[index] : 0,
    ];
    final totalVotes = post.pollVotes > 0
        ? post.pollVotes
        : votes.fold<int>(0, (sum, count) => sum + count);
    final hasEnded =
        post.pollEndTime != null && !post.pollEndTime!.isAfter(DateTime.now());
    final showResults = post.hasVoted || hasEnded;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF242526) : const Color(0xFFF8FAFC);
    final borderColor = isDark ? const Color(0xFF2D2E30) : const Color(0xFFE5E7EB);
    final titleColor = isDark ? Colors.white : const Color(0xFF111827);
    final metaColor = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            post.pollQuestion.isNotEmpty ? post.pollQuestion : 'Poll',
            style: TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.w800,
              color: titleColor,
            ),
          ),
          const SizedBox(height: 10),
          for (var index = 0; index < options.length; index++) ...[
            _PostPollOption(
              label: options[index],
              votes: votes[index],
              totalVotes: totalVotes,
              selected: post.selectedOptionIndex == index,
              showResults: showResults,
              voters: post.pollVoters
                  .where((voter) => voter.optionIndex == index)
                  .toList(growable: false),
              enabled: !isBusy && !hasEnded,
              onTap: () => onVote(index),
            ),
            if (index != options.length - 1) const SizedBox(height: 8),
          ],
          const SizedBox(height: 10),
          Text(
            _pollMetaText(totalVotes, hasEnded),
            style: TextStyle(
              color: metaColor,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  String _pollMetaText(int totalVotes, bool hasEnded) {
    final voteText = totalVotes == 1 ? '1 vote' : '$totalVotes votes';
    if (hasEnded) {
      return '$voteText - Poll ended';
    }
    final endTime = post.pollEndTime;
    if (endTime == null) {
      return voteText;
    }
    final remaining = endTime.difference(DateTime.now());
    if (remaining.inDays >= 1) {
      return '$voteText - ${remaining.inDays}d left';
    }
    if (remaining.inHours >= 1) {
      return '$voteText - ${remaining.inHours}h left';
    }
    final minutes = remaining.inMinutes.clamp(1, 59);
    return '$voteText - ${minutes}m left';
  }
}

class _PostPollOption extends StatelessWidget {
  const _PostPollOption({
    required this.label,
    required this.votes,
    required this.totalVotes,
    required this.selected,
    required this.showResults,
    required this.voters,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final int votes;
  final int totalVotes;
  final bool selected;
  final bool showResults;
  final List<PollVoterPreview> voters;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ratio = totalVotes <= 0 ? 0.0 : (votes / totalVotes).clamp(0.0, 1.0);
    final percent = (ratio * 100).round();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final optionBgColor = isDark ? const Color(0xFF18191A) : Colors.white;
    final optionBorderColor = selected
        ? const Color(0xFF2563EB)
        : (isDark ? const Color(0xFF2D2E30) : const Color(0xFFE5E7EB));
    final fillBgColor = selected
        ? (isDark ? const Color(0x4D2563EB) : const Color(0x332563EB))
        : (isDark ? const Color(0x262563EB) : const Color(0xFFEFF4FF));
    final labelTextColor = isDark ? Colors.white : const Color(0xFF111827);
    final percentTextColor = isDark ? const Color(0xFFE2E8F0) : const Color(0xFF374151);

    return Material(
      color: optionBgColor,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          height: showResults && voters.isNotEmpty ? 66 : 44,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: optionBorderColor,
              width: selected ? 1.4 : 1,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              AnimatedFractionallySizedBox(
                duration: const Duration(milliseconds: 520),
                curve: Curves.easeOutCubic,
                alignment: Alignment.centerLeft,
                widthFactor: showResults ? ratio : 0,
                child: ColoredBox(
                  color: fillBgColor,
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                    12, 0, 12, showResults && voters.isNotEmpty ? 18 : 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: labelTextColor,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (selected) ...[
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.check_circle_rounded,
                        size: 18,
                        color: Color(0xFF2563EB),
                      ),
                    ],
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 260),
                      switchInCurve: Curves.easeOut,
                      switchOutCurve: Curves.easeIn,
                      transitionBuilder: (child, animation) {
                        return FadeTransition(
                          opacity: animation,
                          child: SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0.12, 0),
                              end: Offset.zero,
                            ).animate(animation),
                            child: child,
                          ),
                        );
                      },
                      child: showResults
                          ? Padding(
                              key: const ValueKey('poll-percent'),
                              padding: const EdgeInsets.only(left: 8),
                              child: Text(
                                '$percent%',
                                style: TextStyle(
                                  color: percentTextColor,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            )
                          : const SizedBox.shrink(
                              key: ValueKey('poll-percent-hidden'),
                            ),
                    ),
                  ],
                ),
              ),
              if (showResults && voters.isNotEmpty)
                Positioned(
                  left: 12,
                  bottom: 7,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 240),
                    child: _PollVoterAvatarStack(
                      key: ValueKey('poll-voters-${voters.length}'),
                      voters: voters,
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

class _PollVoterAvatarStack extends StatelessWidget {
  const _PollVoterAvatarStack({required this.voters, super.key});

  final List<PollVoterPreview> voters;

  @override
  Widget build(BuildContext context) {
    final visible = voters.take(5).toList(growable: false);
    final extra = voters.length - visible.length;
    const avatarSize = 22.0;
    const overlap = 14.0;
    final width = visible.isEmpty
        ? 0.0
        : avatarSize + ((visible.length - 1) * overlap) + (extra > 0 ? 30 : 0);

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final optionBgColor = isDark ? const Color(0xFF18191A) : Colors.white;

    return SizedBox(
      width: width,
      height: avatarSize,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (var index = 0; index < visible.length; index++)
            Positioned(
              left: index * overlap,
              child: _PollVoterAvatar(voter: visible[index], size: avatarSize),
            ),
          if (extra > 0)
            Positioned(
              left: visible.length * overlap,
              child: Container(
                width: 28,
                height: avatarSize,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFFE5E7EB) : const Color(0xFF111827),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: optionBgColor, width: 1.5),
                ),
                child: Text(
                  '+$extra',
                  style: TextStyle(
                    color: isDark ? const Color(0xFF111827) : Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PollVoterAvatar extends StatelessWidget {
  const _PollVoterAvatar({required this.voter, required this.size});

  final PollVoterPreview voter;
  final double size;

  @override
  Widget build(BuildContext context) {
    final avatarUrl = voter.avatarUrl.trim();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final optionBgColor = isDark ? const Color(0xFF18191A) : Colors.white;

    return Tooltip(
      message: voter.displayName,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isDark ? const Color(0xFF2D2E30) : const Color(0xFFE5E7EB),
          border: Border.all(color: optionBgColor, width: 1.5),
        ),
        clipBehavior: Clip.antiAlias,
        child: avatarUrl.isEmpty
            ? Center(
                child: Text(
                  voter.initials,
                  style: TextStyle(
                    color: isDark ? Colors.white : const Color(0xFF111827),
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              )
            : Image.network(
                ApiConfig.assetUrl(avatarUrl),
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Center(
                  child: Text(
                    voter.initials,
                    style: TextStyle(
                      color: isDark ? Colors.white : const Color(0xFF111827),
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}
