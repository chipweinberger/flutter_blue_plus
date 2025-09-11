The following was requested to be changed in a PR review: 

" This does not follow FBP conventions.

All java code should be in a single file
All iOS code should be in a single file & in obj-c
all messages should start with Bm and be in the bm_messages.dart file
messages should not be their own java or obj-c classes. follow the existing FBP code
no need for "MarshallingUtil" or the logging changes. that should be in a different PR
case L2CapMethodNames.CONNECT_TO_L2CAP_CHANNEL should just be "connectToL2CapChannel"
you should not add any dependencies to the example app
basically, you're not following FBP conventions at all."