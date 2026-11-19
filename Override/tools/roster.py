"""OVERRIDE droid roster (original designs). The first digit is the class."""

# weapon kinds
W_NONE, W_ZAP, W_LASER, W_TWIN, W_RAPID, W_CANNON = range(6)
WEAPON_NAMES = ['NONE', 'ARC ZAPPER', 'LASER', 'TWIN LASER', 'PULSE GUN', 'PLASMA CANNON']
# weapon: (shot speed px/frame, damage, reload frames, shot life frames)
WEAPONS = {
    W_NONE: (0, 0, 0, 0),
    W_ZAP: (3, 4, 22, 9),
    W_LASER: (4, 6, 18, 16),
    W_TWIN: (4, 6, 16, 16),
    W_RAPID: (5, 4, 7, 14),
    W_CANNON: (3, 14, 26, 20),
}

# number, name, energy, speed (1/16 px per frame), weapon, aggression 0-3, height text, blurb
ROSTER = [
    (0, 'LINK PROBE', 40, 30, W_NONE, 0, 'PROTOTYPE LINK UNIT. UNARMED. CAN SEIZE ANY DROID IT TOUCHES.'),
    (104, 'DUSTER', 20, 14, W_NONE, 0, 'DECK SWEEPER. SLOW AND HARMLESS. EASY TO SEIZE.'),
    (152, 'COURIER', 22, 24, W_NONE, 0, 'MESSAGE RUNNER. QUICK ON ITS WHEELS.'),
    (218, 'STEWARD', 28, 18, W_ZAP, 1, 'CABIN SERVICE UNIT WITH A STUN ARC.'),
    (263, 'WELDER', 34, 16, W_ZAP, 1, 'REPAIR DROID. ITS TORCH MAKES A FAIR WEAPON.'),
    (307, 'PORTER', 52, 12, W_NONE, 1, 'CARGO HAULER. HEAVY PLATING, NO GUNS.'),
    (355, 'TECHNICIAN', 36, 20, W_LASER, 1, 'SYSTEMS TECH WITH A CUTTING LASER.'),
    (408, 'MEDIC', 40, 20, W_ZAP, 1, 'SICKBAY UNIT. TOUGHER THAN IT LOOKS.'),
    (461, 'SENTRY', 46, 18, W_LASER, 2, 'SECURITY POST DROID. SHOOTS ON SIGHT.'),
    (524, 'SURVEYOR', 44, 30, W_LASER, 2, 'SCOUT FRAME. FAST AND ALERT.'),
    (587, 'WARDEN', 56, 20, W_TWIN, 2, 'BRIG GUARD WITH TWIN LASERS.'),
    (632, 'ENFORCER', 64, 22, W_TWIN, 3, 'RIOT UNIT. ARMOURED AND ANGRY.'),
    (668, 'BULWARK', 90, 14, W_LASER, 2, 'WALKING BLAST SHIELD. HARD TO STOP.'),
    (705, 'TROOPER', 70, 24, W_RAPID, 3, 'BATTLE DROID WITH A PULSE GUN.'),
    (773, 'HUNTER', 66, 32, W_RAPID, 3, 'PURSUIT FRAME. FAST AND RELENTLESS.'),
    (817, 'MARSHAL', 84, 22, W_CANNON, 3, 'COMMAND GUARD WITH A PLASMA CANNON.'),
    (856, 'DREADNOUGHT', 120, 14, W_CANNON, 2, 'SIEGE DROID. VERY SLOW, VERY TOUGH.'),
    (908, 'PREFECT', 100, 26, W_CANNON, 3, 'THE SHIP MIND\'S OWN BODYGUARD.'),
    (960, 'OVERMIND', 160, 20, W_CANNON, 3, 'THE ROGUE SHIP MIND IN A BATTLE FRAME.'),
]

NTYPES = len(ROSTER)
TYPE_OF = {r[0]: i for i, r in enumerate(ROSTER)}


def cls(num):
    return num // 100


def score_value(num):
    return 50 + cls(num) * 75
