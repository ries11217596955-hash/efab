# ROUTE CHANGE REQUEST

ID:
PHASE164N_STOP_SIDE_CONVEYOR_AND_TARGET_REAL_SELF_BUILD_INPUT

Reason:
Owner correctly identified that the previous direction was growing a side process instead of feeding the real Builder self-build process.

Old wrong direction:
owner candidate -> adapter -> request -> consumer -> atom -> admission gate

Correct direction:
owner candidate/material -> PHASE87 decision evidence/input -> PHASE88 self-build program generator -> PHASE89 admission -> PHASE90 execution

Requested next action:
PHASE164O_BUILD_OWNER_MATERIAL_INPUT_FOR_REAL_SELF_BUILD_DECISION_KERNEL

Safety:
No deletion now.
PHASE164K/L/M remain archived as evidence until a deliberate cleanup pass.
