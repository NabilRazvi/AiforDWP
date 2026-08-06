# Triage Summary: T-1005 Teams Audio Dead on Three Machines in Same Meeting Room

## Summary (one line)
Teams meeting room audio is non-functional on three machines in the same room, indicating a likely shared room environment, peripheral, or configuration issue (to-verify root cause).

## Impact (who/how many/business urgency)
- Who affected: Users attempting Teams calls/meetings from one meeting room.
- How many affected: Three room machines confirmed.
- Business urgency: High if the room is used for scheduled meetings and stakeholder calls (to-verify meeting criticality).

## Known facts
- Ticket ID: T-1005.
- Reported issue: Teams audio is dead.
- Scope pattern: Three machines in the same meeting room are affected.
- Symptom context: Common location suggests a shared dependency issue (to-verify).

## Missing information to gather
1. Whether issue is microphone only, speaker only, or both input/output paths (to-verify).
2. Exact Teams call test results on each machine and whether failure is consistent across all meetings (to-verify).
3. Audio device inventory in room: dock, USB speakerphone, headset, display audio, conferencing bar (to-verify).
4. Whether affected machines share the same dock, USB hub, or room AV hardware chain (to-verify).
5. Windows default playback/recording device selection on each machine (to-verify).
6. Whether audio works outside Teams (system sounds, browser media, other apps) (to-verify).
7. Whether Teams client updates, policy changes, or driver updates were applied recently (to-verify).
8. Whether issue occurs for multiple user profiles on the same devices (to-verify).
9. Any muted hardware controls on room devices/cables and physical connection status (to-verify).
10. Whether another room with similar setup is unaffected (to-verify comparator).

## Likely catagory
Collaboration tools / Teams endpoint audio: multi-device meeting room audio failure (to-verify).

## First diagnostic step
Perform a controlled Teams test call on one affected machine while validating Windows playback/recording device selection and physical AV chain connectivity, then compare against a known-good room setup to isolate shared hardware/configuration factors (to-verify).
