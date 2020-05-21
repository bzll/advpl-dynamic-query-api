#include 'protheus.ch'
#include 'restful.ch'

#xtranslate @{Header <(cName)>} => ::GetHeader( <(cName)> )
#xtranslate @{Param <n>} => ::aURLParms\[ <n> \]
#xtranslate @{EndRoute} => EndCase
#xtranslate @{Route} => Do Case
#xtranslate @{When <path>} => Case NGIsRoute( ::aURLParms, <path> )
#xtranslate @{Default} => Otherwise

//-------------------------------------------------------------------
/*/{Protheus.doc} wsService
Serviço REST para execução de querys dinâmicas
@author  ciro.chagas
@since   20-05-2020
@version 1
/*/
//-------------------------------------------------------------------
User Function wsService()
return nil

WSRestFul restQuery Description "WebService REST para Integracao"
	WsMethod Get Description "Retorno genérico de dados via Get" wsSyntax "/get/{method}"
End WSRestFul

//-------------------------------------------------------------------
/*/{Protheus.doc} method
Método GET para execução da Query
@author  ciro.chagas
@since   20-05-2020
@version 1
/*/
//-------------------------------------------------------------------
WsMethod Get WsService restQuery
	Local	oResponse		:= JSONObject():New()
	Local	cJson			:= ::GetContent()
	Local	nX			:= 0
	Private	oParser			:= nil
	
	::SetContentType('application/json')
	@{Route}
		@{When '/query'}
			If FwJsonDeserialize(cJson,@oParser)
				If FwSchJSON(@oResponse)
					If FWExecQuery(@oResponse,::aQueryString)
						::SetResponse(FwJsonSerialize(oResponse))
					Else
						::SetStatus(400)
						::SetResponse(FwJsonSerialize(oResponse))
					EndIf
				Else
					::SetStatus(400)
					::SetResponse(FwJsonSerialize(oResponse))
				EndIf
			Else
				SetRestFault(400,'Invalid content in the body JSON')
				return .F.
			EndIf
		@{Default}
			SetResponse(400,'Unknow route')
			return .F.
	@{EndRoute}
return .T.

//-------------------------------------------------------------------
/*/{Protheus.doc} FWSchJSON
Função responsável em validar o Schema do Body
@author  ciro.chagas
@since   20-05-2020
@version 1
/*/
//-------------------------------------------------------------------
Static Function FwSchJSON(oResponse)
	Local	lRet	:= 	.T.
	Local	nX	:= 	0
	Local	aErrors	:= 	{}

	If Type("oParser:query") <> "U"
		If ValType(oParser:query) <> "C"
			aAdd(aErrors,{1,"query","Invalid content type, try 'character'"})
			lRet	:= .F.
		EndIf
	Else
		aAdd(aErrors,{0,"query","The value is necessary"})
		lRet	:= .F.
	EndIf

	If len(aErrors) > 0
		oResponse['message']:=	"Schema failure"
		oResponse['errors']	:=	{}
		For nX := 1 to len(aErrors)
			aAdd(oResponse['errors'], JSONObject():New())
			oResponse['errors'][nX]['id']		:= aErrors[nX,1]
			oResponse['errors'][nX]['field']	:= aErrors[nX,2]
			oResponse['errors'][nX]['description']	:= aErrors[nX,3]
		Next nX
	EndIf
return	lRet

//-------------------------------------------------------------------
/*/{Protheus.doc} FWExecQuery
Função responsável em realizar a execução da Query
@author  ciro.chagas
@since   20-05-2020
@version 1
/*/
//-------------------------------------------------------------------
Static Function FWExecQuery(oResponse,aQueryString)

	Local	cQuery		:= oParser:query
	Local	cAlias		:= GetNextAlias()
	Local	nCount		:= 0
	Local	aArea		:= GetArea()
	Local	cError		:= ""
	Local	bError		:= ErrorBlock({|oError| cError	:= oError:Description})
	Local	lRet		:= .t.
	Local	aStruct		:= {}
	Local	nX		:= 0
	Local	nRecord		:= 0
	Local 	nRows		:= GetNewPar('CN_QRLMROWS',2000)	// Controla a qtde de linhas impressas no response
	Local 	nColumns	:= GetNewPar('CN_QRLMCOLS',40)		// Controla a qtde de colunas impressas no response
	Local	lMaskDate	:= GetNewPar('CN_QRMASK',.F.)		// Controla se tipo Date usará a máscara yyyy-MM-dd
	Local	nPosAux		:= 0
	Local	cExpression	:= ""
	Default	aQueryString	:= {}

	// Por se tratar de REST, caso dê algum problema retornará Internal Error, então, garanto mais detalhes 
	// neste cenário utilizando Try/Catch
	Begin Sequence
		// Leitura da Query String recebida na requisição
		If len(aQueryString) > 0
			// Atributo do Limite de Colunas a ser impresso
			nPosAux	:= aScan(aQueryString,{|x| Lower(AllTrim(x[1])) == 'limitcolumns' })
			If nPosAux > 0
				If aQueryString[nPosAux,2] == "none"	// Caso seja 'none', vou considerar que não há limitação
					nColumns	:= -1
				Else
					nColumns	:= Val(aQueryString[nPosAux,2])
					// Por algum motivo receber 0, para que seja impresso ao menos uma coluna, forço 1
					nColumns	:= IIf(nColumns = 0,1,nColumns)	
				EndIf
			EndIf

			// Atributo do Limite de Linhas a ser impresso
			nPosAux	:= aScan(aQueryString,{|x| Lower(AllTrim(x[1])) == 'limitrows' })
			If nPosAux > 0
				If aQueryString[nPosAux,2] == "none"	// Caso seja 'none', vou considerar que não há limitação
					nRows	:= -1
				Else
					nRows	:= Val(aQueryString[nPosAux,2])
					// Por algum motivo receber 0, para que seja impresso ao menos uma linha, forço 1
					nRows	:= IIf(nRows = 0,1,nRows)
				EndIf
			EndIf

			// Atributo da Máscara de Data, caso o valor seja true, será considerado
			nPosAux	:= aScan(aQueryString,{|x| Lower(AllTrim(x[1])) == 'maskdate' })
			If nPosAux > 0
				lMaskDate	:= AllTrim(Lower(aQueryString[nPosAux,2])) == "true"
			EndIf
		EndIf			

		dbUseArea(.T.,'TOPCONN', TCGenQry(,,cQuery),cAlias, .F., .T.)
		dbSelectArea(cAlias)

		(cAlias)->(dbGoTop())
		(cAlias)->(dbEval({||nCount++}))
		(cAlias)->(dbGoTop())
		
		oResponse['data']			:= {}

		If nCount > 0
			aStruct	:= (cAlias)->(dbStruct())
			// Imprimo a quantidade de linhas até a quantidade definida na variável nRows
			While ! (cAlias)->(EoF()) .and. IIf(nRows > 0,(cAlias)->(Recno()) <= nRows,.T.)
				nRecord	:= (cAlias)->(Recno())
				aAdd(oResponse['data'], JSONObject():New())
				For nX := 1 to len(aStruct)
					// Imprimo a quantidade de colunas até a quantidade definida na variável nColumns
					If nColumns > 0
						If nX > nColumns
							Exit
						EndIf
					EndIf
					If aStruct[nX,2] == "C"
						cExpression	:= "AllTrim((cAlias)->"+aStruct[nX,1]+")"
						// Em algumas querys, mesmo o campo na SX3 sendo data, recebo na estrutura como Caractere, 
						// então, valido se é um destes casos na função FWVldDate
						If FWVldDate(&(cExpression)) .and. lMaskDate
							cExpression	:= "FWFormatDate(,(cAlias)->"+aStruct[nX,1]+")"
						EndIf
					ElseIf aStruct[nX,2] == "D" .and. lMaskDate
						cExpression	:= "FWFormatDate((cAlias)->"+aStruct[nX,1]+")"
					Else
						cExpression	:= "(cAlias)->"+aStruct[nX,1]
					EndIf
					oResponse['data'][nRecord,aStruct[nX,1]]	:= &(cExpression)
				Next nX
				(cAlias)->(dbSkip())
			EndDo
		EndIf

		oResponse['records']		:= nCount
		oResponse['limitRows']		:= nRows
		oResponse['limitColumns']	:= nColumns

		(cAlias)->(dbCloseArea())
	End Sequence
	ErrorBlock(bError)
	If ! Empty(cError)
		oResponse['message']	:= "Fail to execute the query"
		oResponse['errors']	:= {}
		aAdd(oResponse['errors'], JSONObject():New())
		oResponse['errors'][1]['id']		:= 0
		oResponse['errors'][1]['description']	:= cError
		lRet	:= .F.
	EndIf

	RestArea(aArea)

return	lRet

//-------------------------------------------------------------------
/*/{Protheus.doc} FWFormatDate
Função responsável em formatar a Data para o padrão yyyy-MM-dd
A mesma pode receber como primeiro parâmetro um value do tipo Date
Ou outro parâmetro do tipo Char
@author  ciro.chagas
@since   20-05-2020
@version 1
/*/
//-------------------------------------------------------------------
Static Function FWFormatDate(dDate,cDate)

	Local cRet	:= ""
	Default	dDate	:= CToD("  /  /    ")
	Default cDate	:= ""

	If ! Empty(dDate)
		cRet := DTOS(dDate)
		cRet := Substring(cRet,1,4) + "-" + Substring(cRet,5,2) + "-" + Substring(cRet,7,2)
	ElseIf ! Empty(cDate)
		cRet := Substring(cDate,1,4) + "-" + Substring(cDate,5,2) + "-" + Substring(cDate,7,2)
	EndIf

Return(cRet)

//-------------------------------------------------------------------
/*/{Protheus.doc} FWVldDate
Função responsável para validar se um texto pode ser uma data válida
@author  ciro.chagas
@since   20-05-2020
@version 1
/*/
//-------------------------------------------------------------------
Static Function FWVldDate(cDate)

	Local	lRet	:= .T.
	Local	nX	:= 1
	Local	cError	:= ""
	Local	xDate	:= nil
	Local	bError	:= ErrorBlock({|oError| cError	:= oError:Description})	// Trativa Try/Catch

	cDate	:= StrTran(cDate,"-","")
	
	For nX := 1 to len(cDate)
		// Tabela ASCII - 0 a 9
		If ! (Asc(Substring(cDate,nX,1)) >= 48 .and. Asc(Substring(cDate,nX,1)) <= 57)
			lRet	:= .F.
			Exit
		EndIf
	Next nX

	If lRet
		Begin Sequence
			xDate	:= SToD(cDate)
		End Sequence
		ErrorBlock(bError)
		If ! Empty(cError)
			lRet	:= .F.
		ElseIf ValType(xDate) <> "D"
			lRet	:= .F.
		ElseIf Empty(xDate)
			lRet	:= .F.
		EndIf
	EndIf

Return	lRet
