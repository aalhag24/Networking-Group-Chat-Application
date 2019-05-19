#include "../../includes/am_types.h"

configuration ForwardC {
	provides {
		interface SimpleSend as RouteSender;
		interface Receive as RouteReceiver;
	}
}
implementation {
	components ForwardP;
	components LinkStateRouteC;

	components new SimpleSendC(AM_FORWARD);
	components new AMReceiverC(AM_FORWARD);

	ForwardP.Router -> LinkStateRouteC.LinkStateRoute;
	ForwardP.Sender -> SimpleSendC;
	ForwardP.Receiver -> AMReceiverC;

	RouteSender = ForwardP.RouteSender;
	RouteReceiver = ForwardP.RouteReceiver;
}
