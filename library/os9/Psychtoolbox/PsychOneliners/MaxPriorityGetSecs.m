function maxPriority=MaxPriorityGetSecs% maxPriority=MaxPriorityGetSecs% Returns the maximum priorityLevel at which GetSecs operates normally on% this computer. This routine is slow and meant solely for testing. Your% programs should call MaxPriority instead, which is faster and easier to% use.% % MaxPriorityGetSecs will be 7 on PowerMacs with Mac OS 8.6 or better and 0.5 on% all other Macs. PowerMac with Mac OS 8.6 or better provide the UpTime trap in InterfaceLib. % Other Macs don't. % % See Rush, MaxPriority.% 6/1/97	dgp	Wrote it.% 1/4/98	dgp	Keep trying until we get 200 ms interval. This should%				eliminate spurious results due to rare long interrupts of%				the initial timing interval.% 2/8/98	dgp added priority 0.5.% 7/17/98	dgp   Using enhanced Rush, use easy-to-read cell array for string.% 8/7/98	dgp   Updated text for Mac OS 8.5.% 2/4/00	dgp   Updated text for Mac OS 9.GetSecs;i=0;t=0;n=4000;loop={	't=GetSecs;'	'for i=1:n;'	'end;'	't=GetSecs-t;'};Rush(loop,0);while abs(t/0.2-1)>0.1	n=round(n*0.2/t);	% adjust n to produce roughly 0.2 s interval.	Rush(loop,0);endtCorrect=t;maxPriority=0;for p=[0.5 1:7]	Rush(loop,p);	if abs(t/tCorrect-1)<0.3	% allow for random interrupts		maxPriority=p;	% GetSecs is ok	else		break			% GetSecs failed	endend