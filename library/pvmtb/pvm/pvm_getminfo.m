%PVM_GETMINFO		Informaci�n sobre mensajes
%
%  [info msginfo] = pvm_getminfo(bufid)	* msginfo: struct [len,ctx,tag,wid,
%							   enc,crc,src,dst]
%
%  bufid   (int)   identificador del buffer conteniendo el mensaje
%  info    (int)   c�digo de retorno
%       0  PvmOk
%      -2  PvmBadParam
%     -16  PvmNoSuchBuf
%
%  msginfo (struct pvmminfo) informaci�n sobre el mensaje
%                            todos los campos son (int)
%	len	longitud del mensaje
%	ctx	contexto
%	tag	c�digo (etiqueta)
%	wid	identificador de espera (wait id)
%	enc	codificaci�n (XDR, raw, in-place)
%	crc	checksum
%	src	tid fuente
%	dst	tid destino
%
%  Implementaci�n MEX completa: src/pvm_getminfo.c, pvm/MEX/pvm_getminfo.mexlx
