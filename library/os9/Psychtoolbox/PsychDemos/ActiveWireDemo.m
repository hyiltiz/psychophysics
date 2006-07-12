function ActiveWireDemo% ActiveWireDemo% % Demonstrates the use of ActiveWire extension (OS9 and Win)  % to control PicoStar's USB ActiveWire device.  % web http://www.activewireinc.com ;% % Also see PsychHardware.%   8/22/01  	awi  	wrote it%	11/27/01	awi		added warning about driver bug%	11/29/01	awi		removed warning about bug, ActiveWire fixed it. LightOnMat = [repmat(0,1,15) 1];LightOffMat = zeros(1,16);DirectionMat = [repmat(0,1,15) 1];  ActiveWire('CloseAll');ActiveWire(1,'OpenDevice');ActiveWire(1,'SetDirection',DirectionMat);ActiveWire(1,'SetPort',LightOffMat);halfPeriod(1) = 0.2;halfPeriod(2) = 0.05;halfPeriod(3) = 0.02;numLoops(1) = 10;numLoops(2) = 10;numLoops(3) = 100;LEDmessage{1} = 'Press a keyboard key to blink the LED ten times.\n';LEDmessage{2} = 'Press a keyboard key to blink faster.\n';LEDmessage{3} = 'Press again to blink faster.\n';for i = 1:3    fprintf(LEDmessage{i});    GetChar;	for j = 1:10	    ActiveWire(1,'SetPort',LightOnMat);	    WaitSecs(halfPeriod(i));	    ActiveWire(1,'SetPort',LightOffMat);	    WaitSecs(halfPeriod(i));	end endActiveWire(1,'CloseDevice');