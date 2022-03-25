# only need this the FIRST time I register.
from gym.envs.registration import register
register(
    id='vrgym-v0',
    entry_point='gym_vr.envs:VRShapingEnv',
)

# register(
#     id='vrgym-v1',
#     entry_point='gym_vr.envs:VRShapingEnv2',
# )

# register(
#     id='vrgym-v2',
#     entry_point='gym_vr.envs:VRShapingEnv3',
# )

# register(
#     id='vrgym-v3',
#     entry_point='gym_vr.envs:VRShapingEnv4',
# )