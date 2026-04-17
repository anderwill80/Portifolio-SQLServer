/*
====================================================================================================================================================================================
WREL071 - Transferencia entre estoques via movimentos internos
====================================================================================================================================================================================
Histórico de alterações
====================================================================================================================================================================================
16/01/2025 - WILLIAM
	- Alteração nos parametros da SP "usp_GetCodigosProdutos";
15/01/2025 - WILLIAM
	- Conversão do script SQL para StoredProcedure;
	- Inclusão do @empcod nos parâmetros de entrada da SP;	
	- Utilização da SP "usp_GetCodigosProdutos", para obter os códigos dos produtos conforme filtro do usuário, isso evitará redundancia de código nos relatórios;
************************************************************************************************************************************************************************************
*/ 
 CREATE PROCEDURE [dbo].[usp_RS_TransferEstoquesViaMovInternos]
--ALTER PROCEDURE [dbo].[usp_RS_TransferEstoquesViaMovInternos]
	@empcod smallint,
	@dataAberturaDe datetime,
	@dataAberturaAte datetime,
	@codigoProduto varchar(5000),
	@descricaoProduto varchar(60),
	@documento int,
	@tipoDeMovimento varchar(5000),
	@estoqueOrigem varchar(500),
	@estoqueDestino varchar(500),
	@statusCodigoDocumento varchar(500),
	@statusCodigoItem varchar(500),
	@prioridade varchar(100)
AS
BEGIN
	SET NOCOUNT ON;
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	DECLARE @codigoEmpresa smallint, 
			@Data_De datetime, @Data_Ate datetime, @PROCOD varchar(5000), @PRODES varchar(60), @MVIDOC int, @TiposDeMovimento varchar(5000), @EstoquesOrigem varchar(500),
			@EstoquesDestino varchar(500), @StaCodigoDocumento varchar(500), @StaCodigoItem varchar(500), @Prioridades varchar(100);

-- Desativando a detecção de parâmetros(Parameter Sniffing)
	SET @codigoEmpresa = @empcod;
	SET @Data_De = (SELECT ISNULL(@dataAberturaDe, '17530101'));
	SET @Data_Ate = (SELECT ISNULL(@dataAberturaAte, GETDATE()));
	SET @PROCOD = @codigoProduto;
	SET @PRODES = RTRIM(LTRIM(UPPER(@descricaoProduto)));
	SET @MVIDOC = @documento;
	SET @TiposDeMovimento = @tipoDeMovimento;
	SET @EstoquesOrigem = @estoqueOrigem;
	SET @EstoquesDestino = @estoqueDestino;
	SET @StaCodigoDocumento = @statusCodigoDocumento;
	SET @StaCodigoItem = @statusCodigoItem;
	SET @Prioridades = @prioridade;

-- Uso da funcao split, para as clausulas IN()
	-- Tipos de movimento
		If object_id('TempDB.dbo.#TIPOSMOV') is not null
			DROP TABLE #TIPOSMOV;
		select 
			elemento as valor
		Into #TIPOSMOV
		From fSplit(@TiposDeMovimento, ',')
		OPTION(MAXRECURSION 0)
	-- Estoques de origem
		If object_id('TempDB.dbo.#ESTORIGEM') is not null
			DROP TABLE #ESTORIGEM;
		select 
			elemento as valor
		Into #ESTORIGEM
		From fSplit(@EstoquesOrigem, ',')
	-- Estoques de destino
		If object_id('TempDB.dbo.#ESTDESTINO') is not null
			DROP TABLE #ESTDESTINO;
		select 
			elemento as valor
		Into #ESTDESTINO
		From fSplit(@EstoquesDestino, ',')
	-- Status documento
		If object_id('TempDB.dbo.#STADOCUMENTO') is not null
			DROP TABLE #STADOCUMENTO;
		select 
			elemento as valor
		Into #STADOCUMENTO
		From fSplit(@StaCodigoDocumento, ',')
	-- Status item
		If object_id('TempDB.dbo.#STAITEM') is not null
			DROP TABLE #STAITEM;
		select 
			elemento as valor
		Into #STAITEM
		From fSplit(@StaCodigoItem, ',')
	-- Prioridades
		If object_id('TempDB.dbo.#PRIORIDADES') is not null
			DROP TABLE #PRIORIDADES;
		select 
			elemento as valor
		Into #PRIORIDADES
		From fSplit(@Prioridades, ',')
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Filtra produto pelo código ou código de barras, se vazio filtra todos os código da TBS010
	IF object_id('tempdb.dbo.#TBS010') is not null
		drop table #TBS010;	

	CREATE TABLE #TBS010 (PROCOD varchar(15))

	INSERT INTO #TBS010
	EXEC usp_GetCodigosProdutos @codigoEmpresa, @PROCOD, @PRODES, 0, ''

	-- select PROCOD FROM #T UNION select case when @PROCOD <> '' then '0' else '' end

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Pegar os documentos filtrados somente na TBS037, depois buscar nas outras tabelas (filhos)

	IF object_id('tempdb.dbo.#Documento') is not null
		DROP TABLE #Documento;

	SELECT 
		-- top 5000
		MVIEMPCOD AS codigoEmpresa,
		MVIDOC as documento,
		case MVIPRIORI 
			when 0 then 'Urgente' 
			when 1 then 'Delivery' 
			when 9 then 'Normal' 
			else ''
		end as prioridade,
		A.MVITRM as tipoRm,
		CONVERT(DATETIME,(CONVERT(DATE,MVIDATLAN))) + MVIHORLAN as dataHoraAbertura,
		CONVERT(DATETIME,(CONVERT(DATE,MVIDATEFE))) + MVIHOREFE as dataHoraEfetivacao,
		RTRIM(LTRIM(STR(A.TMVCOD))) + ' - ' + (SELECT dbo.PrimeiraMaiuscula(TMVDES) FROM TBS033 D (NOLOCK) WHERE A.TMVCOD = D.TMVCOD) as tipoMovimentoNome ,
		MVISTATUS as statusCodigo,
		case MVISTATUS
			when 0 then 'Aberto'
			when 1 then 'Imprimir'
			when 2 then 'Separacao'
			when 3 then 'Conferencia'
			when 4 then 'Divergente'
			when 5 then 'Efetivado' 
			when 6 then 'Efetivado (D)'
			else ''
		end as statusNome,

		RTRIM(LTRIM(STR(A.CCSCOD))) + ' - ' + ISNULL((SELECT dbo.PrimeiraMaiuscula(CCSNOM) FROM TBS036 C (NOLOCK) WHERE C.CCSCOD = A.CCSCOD),'') AS usuarioAbertura,
		CASE WHEN MVICCSNOM IS NULL OR MVICCSNOM = ''
			THEN ''
			ELSE RTRIM(LTRIM(STR(A.MVICCSCOD))) + ' - ' + RTRIM(LTRIM(dbo.PrimeiraMaiuscula(MVICCSNOM)))
		END as usuarioEfetivacao,

		CASE WHEN A.MVICCSCOD = 0 THEN dbo.HORASTRABA(CONVERT(DATETIME,(CONVERT(DATE,MVIDATLAN))) + MVIHORLAN ,CONVERT(DATETIME,(CONVERT(DATE,MVIDATEFE))) + MVIHOREFE) ELSE '' END AS tempoEmAberto,
		CASE WHEN A.MVICCSCOD <> 0 THEN dbo.HORASTRABA(CONVERT(DATETIME,(CONVERT(DATE,MVIDATLAN))) + MVIHORLAN ,CONVERT(DATETIME,(CONVERT(DATE,MVIDATEFE))) + MVIHOREFE) ELSE '' END AS tempoDeAtendimento,

		substring(dbo.HORASTRABA(A.MVIDATLAN + A.MVIHORLAN,A.MVIDATEFE + A.MVIHOREFE),1,4) * 60 + substring(dbo.HORASTRABA(A.MVIDATLAN + A.MVIHORLAN,A.MVIDATEFE + A.MVIHOREFE),6,2) as minutos,

		CASE WHEN A.MVILOCORI = 0
			THEN ''
			ELSE RTRIM(LTRIM(STR(A.MVILOCORI))) + ' - ' + (SELECT dbo.PrimeiraMaiuscula(LESDES) FROM TBS034 D (NOLOCK) WHERE A.MVILOCORI = D.LESCOD) 
		END AS localOrigem ,

		CASE WHEN A.MVILOCDES = 0
			THEN ''
			ELSE RTRIM(LTRIM(STR(A.MVILOCDES))) + ' - ' + (SELECT dbo.PrimeiraMaiuscula(LESDES) FROM TBS034 D (NOLOCK) WHERE A.MVILOCDES = D.LESCOD)
		END AS localDestino,

		rtrim(ltrim(A.MVIOBS)) as observacao
	INTO #Documento
	FROM TBS037 A (NOLOCK) 
	WHERE 
	CONVERT(DATE,MVIDATLAN) BETWEEN @Data_De AND @Data_Ate AND 
	A.TMVCOD IN (SELECT valor FROM #TIPOSMOV) AND
	A.MVILOCORI IN (SELECT valor from #ESTORIGEM) AND
	A.MVILOCDES IN (SELECT valor from #ESTDESTINO) AND
	A.MVIDOC = case when @MVIDOC = 0 then A.MVIDOC else @MVIDOC end AND
	A.MVIPRIORI IN (SELECT valor from #PRIORIDADES)
	ORDER BY 
	MVIDOC 

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- procura na TBS0373 somente LANCAMENTO, ENVIO SEPARACAO, IMPRESSAO SEP, OK SEPARACAO, INICIO CONFERENCIA, OK CONFERENCIA, OK CONFERENCIA(D), IMPRESSAO DIV

	IF object_id('tempdb.dbo.#AcoesDocumento1') is not null
		drop table #AcoesDocumento1;

	SELECT 
		ROW_NUMBER() OVER (Partition by A.MVIEMPCOD, A.MVIDOC order by A.MVIDOC, MIN(MVILOGSEQ), MIN(MVILOGDAT + MVILOGHOR)) AS idLogAcao,
		A.MVIEMPCOD as codigoEmpresa,
		A.MVIDOC as documento,
		prioridade,
		tipoRm,
		tipoMovimentoNome,
		localOrigem,
		localDestino,
		dbo.PrimeiraMaiuscula(MVILOGACA) as acao,
		rtrim(ltrim(str(MVILOGOPECOD))) + ' - ' + rtrim(ltrim(dbo.PrimeiraMaiuscula(MVILOGOPENOM))) as operador,
		MIN(MVILOGDAT + MVILOGHOR) as dataHoraInicioOperacao,
		rtrim(ltrim(str(COUNT(*)))) as tentativas
	INTO #AcoesDocumento1
	FROM TBS0373 A (NOLOCK)
		inner join #Documento B on A.MVIEMPCOD = B.codigoEmpresa and A.MVIDOC = B.documento and B.tipoRm = 2
	WHERE 
		MVILOGACA in ('LANCAMENTO', 'ENVIO SEPARACAO', 'IMPRESSAO SEP', 'OK SEPARACAO', 'INICIO CONFERENCIA', 'OK CONFERENCIA', 'OK CONFERENCIA(D)', 'IMPRESSAO DIV', 'EFETIVACAO')
	GROUP BY 
		A.MVIEMPCOD,
		A.MVIDOC,
		MVILOGACA,
		MVILOGOPECOD,
		MVILOGOPENOM,
		prioridade,
		tipoRm,
		tipoMovimentoNome,
		localOrigem,
		localDestino
	ORDER BY 
		A.MVIDOC, 
		MIN(MVILOGSEQ),
		MIN(MVILOGDAT + MVILOGHOR)  

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Colocar a data de inicio do log anterior como data final do log posterior

	IF object_id('tempdb.dbo.#AcoesDocumento2') is not null
		drop table #AcoesDocumento2;

	SELECT 
		*, 
		isnull((select dataHoraInicioOperacao from #AcoesDocumento1 b where a.documento = b.documento and a.codigoEmpresa = b.codigoEmpresa and a.idLogAcao + 1 = b.idLogAcao),'17530101') as dataHoraFimOperacao
	INTO #AcoesDocumento2
	FROM #AcoesDocumento1 a
	ORDER BY 
		documento, dataHoraInicioOperacao

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

	-- Deixar as ações no ponto de inserção, com os tempos entre os passos feito,

	IF object_id('tempdb.dbo.#AcoesDocumento3') is not null
		drop table #AcoesDocumento3;

	SELECT 
		idLogAcao,
		codigoEmpresa,
		documento,
		prioridade,
		tipoRm,
		tipoMovimentoNome,
		localOrigem,
		localDestino,
		acao,
		operador,
		dataHoraInicioOperacao,
		dataHoraFimOperacao,
		tentativas,
		'' as tempoEmAberto,

		case when acao = 'Efetivacao'
			then ''
			else 
				case when dataHoraFimOperacao = '17530101'
					then dbo.HORASTRABA(dataHoraInicioOperacao,getdate())
					else dbo.HORASTRABA(dataHoraInicioOperacao,dataHoraFimOperacao) 
				end 
		end as tempoEspera,
		case when acao = 'Efetivacao'
			then 0
			else 
				case when dataHoraFimOperacao = '17530101'
					then substring(dbo.HORASTRABA(dataHoraInicioOperacao,getdate()),1,4) * 60 + substring(dbo.HORASTRABA(dataHoraInicioOperacao,getdate()),6,2)
					else substring(dbo.HORASTRABA(dataHoraInicioOperacao,dataHoraFimOperacao),1,4) * 60 + substring(dbo.HORASTRABA(dataHoraInicioOperacao,dataHoraFimOperacao),6,2)
				end 
		end as tempoEsperaMinutos
	INTO #AcoesDocumento3
	FROM #AcoesDocumento2

	-- select * from #AcoesDocumento3

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Quantificar as ações

	IF object_id('tempdb.dbo.#AcoesDocumento') is not null
		drop table #AcoesDocumento;

	SELECT 
		*,
		case when acao = 'Lancamento' then tempoEsperaMinutos else 0 end as tempoLancamento,
		case when acao = 'Envio Separacao' then tempoEsperaMinutos else 0 end as tempoEnvioSeparacao,
		case when acao = 'Impressao Sep' then tempoEsperaMinutos else 0 end as tempoImpressaoSep,
		case when acao = 'Ok Separacao' then tempoEsperaMinutos else 0 end as tempoOkSeparacao,
		-- case when acao = 'Inicio Conferencia' then tempoEsperaMinutos else 0 end as tempoInicioConferencia,
		case when acao = 'Inicio Conferencia' or acao = 'Ok Conferencia' or acao = 'Ok Conferencia(D)' then tempoEsperaMinutos else 0 end as tempoConferencia,
		case when acao = 'Impressao Div' then tempoEsperaMinutos else 0 end as tempoImpressaoDiv,
		0 as qtdDocumento,
		'' as observacao,
		-1 as statusCodigoDocumento,
		'' as statusNomeDocumento,
		-1 as statusCodigoItem,
		'' as statusNomeItem,
		-1 as item,
		'' as codigo,
		'' as descricao,
		'' as unidadeMedida,
		-1.0000 as quantidadePedida,
		-1.0000 as quantidadeAtendida,
		-1.0000 as quantidadeConferida,
		-1.0000 as quantidadeResiduo,
		-1 as rankDocumento,
		'' as unidadeMediaUsada,
		0 as qtdDocumentoAberto,
		0 as qtdDocumentoImprimir,
		0 as qtdDocumentoSeparacao,
		0 as qtdDocumentoConferencia,
		0 as qtdDocumentoDivergente,
		0 as qtdDocumentoEfetivado,
		0 as qtdDocumentoEfetivadoDivergente,
		0 as qtdDocumentoSemItem,
		0 as qtdItensAtendimentoParcial,
		0 as qtdItensNaoAtendido,
		0 as qtdItensConferencia,
		0 as qtdItensEmdivergencia,
		0 as qtdItensNoProcesso,
		0 as qtdItensOk,
		0 as qtdItensNaoAtendidoConferencia,
		0 as qtdItensParcialConferidos
	INTO #AcoesDocumento
	FROM #AcoesDocumento3

	-- select * from #AcoesDocumento

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- update para pegar a quantide de documentos que estão usando o rm atual, com separaca e conferencia

	BEGIN TRAN
		UPDATE #AcoesDocumento
			SET qtdDocumento = idLogAcao
		WHERE
		idLogAcao = 1

	COMMIT TRAN

	-- select top 1 * from #AcoesDocumento

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

	IF object_id('tempdb.dbo.#Itens') is not null
		DROP TABLE #Itens;

	SELECT
		codigoEmpresa,
		documento,
		prioridade,
		tipoRm,
		tipoMovimentoNome ,
		localOrigem,
		localDestino,
		'' as acao,
		usuarioAbertura,
		dataHoraAbertura,
		dataHoraEfetivacao,
		usuarioEfetivacao,
		tempoEmAberto,
		tempoDeAtendimento,
		minutos,
		0 as tempoLancamento,
		0 as tempoEnvioSeparacao,
		0 as tempoImpressaoSep,
		0 as tempoOkSeparacao,
		0 as tempoConferencia,
		0 as tempoImpressaoDiv,
		0 as qtdDocumento,
		observacao,

		case when B.PROCOD is null 
			then 7
			else statusCodigo
		end as statusCodigoDocumento,

		case when B.PROCOD is null 
			then 'Sem item'
			else statusNome
		end as statusNomeDocumento,

		case when B.PROCOD is null
			then 0
			else
				case when tipoRm <> 0 
					then 
						case when CONVERT(DATE,dataHoraEfetivacao) <> '17530101' AND B.MVIQTDPED <> MVIQTDATD and MVIQTDATD > 0 and MVIQTDATD = MVIQTDCON -- or (CONVERT(DATE,dataHoraEfetivacao) = '17530101' and statusCodigo = 4)
							then 1
							else 
								case when CONVERT(DATE,dataHoraEfetivacao) <> '17530101' AND B.MVIQTDPED <> MVIQTDATD and MVIQTDATD = 0 AND MVIQTDCON = 0
									then 2
									else
										case when CONVERT(DATE,dataHoraEfetivacao) <> '17530101' AND B.MVIQTDPED = MVIQTDATD and MVIQTDATD <> MVIQTDCON
											then 3
											else
												case when CONVERT(DATE,dataHoraEfetivacao) <> '17530101' AND B.MVIQTDPED <> MVIQTDATD and MVIQTDATD = 0 AND MVIQTDCON > 0
													then 7
													else
														case when CONVERT(DATE,dataHoraEfetivacao) <> '17530101' AND B.MVIQTDPED <> MVIQTDATD and MVIQTDATD > 0 and MVIQTDATD <> MVIQTDCON
															then 8
															else
																case when CONVERT(DATE,dataHoraEfetivacao) = '17530101' and statusCodigo = 4
																	then 4
																	else
																		case when CONVERT(DATE,dataHoraEfetivacao) ='17530101' 
																			then 5
																			else 6
																		end
																end
														end
												end
										end
								end
						end
					else
						case when CONVERT(DATE,dataHoraEfetivacao) ='17530101' 
							then 5
							else 6
						end
				end
		end AS statusCodigoItem,

		case when B.PROCOD is null
			then 'Sem item'
			else
				case when tipoRm <> 0 
					then 
						case when CONVERT(DATE,dataHoraEfetivacao) <> '17530101' AND B.MVIQTDPED <> MVIQTDATD and MVIQTDATD > 0 and MVIQTDATD = MVIQTDCON -- or (CONVERT(DATE,dataHoraEfetivacao) = '17530101' and statusCodigo = 4)
							then 'Parcial'
							else 
								case when CONVERT(DATE,dataHoraEfetivacao) <> '17530101' AND B.MVIQTDPED <> MVIQTDATD and MVIQTDATD = 0 AND MVIQTDCON = 0
									then 'Nao Atendido'
									else
										case when CONVERT(DATE,dataHoraEfetivacao) <> '17530101' AND B.MVIQTDPED = MVIQTDATD and MVIQTDATD <> MVIQTDCON
											then 'Conferencia'
											else
												case when CONVERT(DATE,dataHoraEfetivacao) <> '17530101' AND B.MVIQTDPED <> MVIQTDATD and MVIQTDATD = 0 AND MVIQTDCON > 0
													then 'Nao Atendido-Conferencia'
													else
														case when CONVERT(DATE,dataHoraEfetivacao) <> '17530101' AND B.MVIQTDPED <> MVIQTDATD and MVIQTDATD > 0 and MVIQTDATD <> MVIQTDCON
															then 'Parcial-Conferencia'
															else
																case when CONVERT(DATE,dataHoraEfetivacao) = '17530101' and statusCodigo = 4
																	then 'Em divergencia'
																	else
																		case when CONVERT(DATE,dataHoraEfetivacao) ='17530101' 
																			then 'No Processo'
																			else 'Ok'
																		end
																end
														end
												end
										end
								end
						end
					else
						case when CONVERT(DATE,dataHoraEfetivacao) ='17530101' 
							then 'No Processo'
							else 'Ok'
						end
				end
		end as statusNomeItem,
		B.MVIITE AS item,
		isnull(rtrim(ltrim(B.PROCOD)),'') as codigo,
		isnull(rtrim(ltrim(B.MVIPRODES)),'') as descricao,
		isnull(MVIPROUNI,'') as unidadeMedida,
		isnull(MVIQTDPED,0) as quantidadePedida,
		isnull(MVIQTDATD,0) as quantidadeAtendida,
		isnull(MVIQTDCON,0) as quantidadeConferida,
		isnull(MVIQTDRES,0) as quantidadeResiduo,
		ROW_NUMBER() OVER( PARTITION BY A.documento ORDER BY A.documento, MVIITE ) as rankDocumento
	INTO #Itens
	FROM #Documento A 
		LEFT JOIN TBS0371 B (NOLOCK) ON A.documento = B.MVIDOC AND A.codigoEmpresa = B.MVIEMPCOD
	WHERE
		isnull(B.PROCOD,'0') collate database_default IN (select PROCOD FROM #TBS010 UNION select @PROCOD)
		--AND isnull(rtrim(ltrim(B.MVIPRODES)),'') like(case when @PRODES = '' then isnull(rtrim(ltrim(B.MVIPRODES)),'') else ltrim(rtrim(upper(@PRODES))) end )
	ORDER BY
		documento, MVIITE

	-- select * from #Itens where documento = 173156

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Apagar os rankDocumento acima de 1, para que eu possa somar as quantidades de documento

	BEGIN TRAN 
		UPDATE #Itens
			SET rankDocumento = 0
		WHERE
		rankDocumento > 1
	COMMIT TRAN

	-- select * from #Itens 

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Procura a menor unidade na TBS010, mesmo que o produto tenha mudado de unidade

	IF OBJECT_ID ('tempdb.dbo.#Produto') is not null
		DROP TABLE #Produto;	

	SELECT 
		PROEMPCOD AS codigoEmpresa, 
		RTRIM(LTRIM(A.PROCOD)) AS codigo, 

		PROUM1 as unidade1,
		CASE WHEN PROUM1QTD = 1
			THEN RTRIM((SELECT UNIDES FROM TBS011 D (NOLOCK) WHERE A.PROUM1 = D.UNICOD))   
			ELSE
				CASE WHEN PROUM1QTD > 1 
				THEN rtrim(PROUM1) + ' C/' + rtrim(CAST(PROUM1QTD AS DECIMAL(10,0))) +''+ RTRIM(PROUMV) 
				ELSE '' 
			END 
		END as unidadeMedida1,

		PROUM2 as unidade2,
		CASE WHEN PROUM2QTD > 0 
			THEN rtrim(PROUM2) + ' C/' + rtrim(CAST(PROUM2QTD AS DECIMAL(10,0)))+''+ RTRIM(PROUM1) + CASE WHEN PROUM1QTD > 1 THEN ' C/' + rtrim(CAST(PROUM1QTD AS DECIMAL(10,0))) +''+ RTRIM(PROUMV) ELSE '' end
			ELSE '' 
		END as unidadeMedida2,

		PROUM3 as unidade3,
		CASE WHEN PROUM3QTD > 0 
			THEN rtrim(PROUM3) + ' C/' + rtrim(CAST(PROUM3QTD AS DECIMAL(10,0)))+''+ rtrim(PROUM2) + ' C/' + rtrim(CAST(PROUM2QTD AS DECIMAL(10,0)))+''+ RTRIM(PROUM1) + CASE WHEN PROUM1QTD > 1 THEN ' C/' + rtrim(CAST(PROUM1QTD AS DECIMAL(10,0))) +''+ RTRIM(PROUMV) ELSE '' end
			ELSE '' 
		END as unidadeMedida3,

		PROUM4 as unidade4,
		CASE WHEN PROUM4QTD > 0 
			THEN rtrim(PROUM4) + ' C/' + rtrim(CAST(PROUM4QTD AS DECIMAL(10,0)))+''+ rtrim(PROUM3) + ' C/' + rtrim(CAST(PROUM3QTD AS DECIMAL(10,0)))+''+ rtrim(PROUM2) + ' C/' + rtrim(CAST(PROUM2QTD AS DECIMAL(10,0)))+''+ RTRIM(PROUM1) + CASE WHEN PROUM1QTD > 1 THEN ' C/' + rtrim(CAST(PROUM1QTD AS DECIMAL(10,0))) +''+ RTRIM(PROUMV) ELSE '' end
			ELSE '' 
		END as unidadeMedida4
	INTO #Produto
	FROM TBS010 A (NOLOCK)
	WHERE
		PROCOD IN (SELECT distinct codigo from #Itens)

	-- select * from #Produto where codigo = '1080067'

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Quantificar os satus do documento e do item; colocar a unidade de medida usadada com a descrição completa 

	IF OBJECT_ID ('tempdb.dbo.#ItensProduto') is not null
		drop table #ItensProduto;

	SELECT 
		0 as idLogAcao,
		a.*,
		case when a.unidadeMedida = b.unidade1
			then b.unidadeMedida1
			else 
				case when a.unidadeMedida = b.unidade2
					then b.unidadeMedida2
					else 
						case when a.unidadeMedida = b.unidade3
							then b.unidadeMedida3
							else
								case when a.unidadeMedida = b.unidade4
									then b.unidadeMedida4
									else a.unidadeMedida
								end
						end
				end
		end as unidadeMediaUsada,

		case when statusCodigoDocumento = 0 and tipoRm <> 0
			then rankDocumento
			else 0
		end as qtdDocumentoAberto,

		case when statusCodigoDocumento = 1 and tipoRm <> 0
			then rankDocumento
			else 0
		end as qtdDocumentoImprimir,

		case when statusCodigoDocumento = 2 and tipoRm <> 0
			then rankDocumento
			else 0
		end as qtdDocumentoSeparacao,

		case when statusCodigoDocumento = 3 and tipoRm <> 0
			then rankDocumento
			else 0
		end as qtdDocumentoConferencia,

		case when statusCodigoDocumento = 4 and tipoRm <> 0
			then rankDocumento
			else 0
		end as qtdDocumentoDivergente,

		case when statusCodigoDocumento = 5 and tipoRm <> 0
			then rankDocumento
			else 0
		end as qtdDocumentoEfetivado,

		case when statusCodigoDocumento = 6 and tipoRm <> 0
			then rankDocumento
			else 0
		end as qtdDocumentoEfetivadoDivergente,

		case when statusCodigoDocumento = 7 and tipoRm <> 0
			then rankDocumento
			else 0
		end as qtdDocumentoSemItem,

		case when statusCodigoItem = 1 and tipoRm <> 0
			 then 1
			 else 0
		end as qtdItensAtendimentoParcial,

		case when statusCodigoItem = 2 and tipoRm <> 0
			 then 1
			 else 0
		end as qtdItensNaoAtendido,

		case when statusCodigoItem = 3 and tipoRm <> 0
			 then 1
			 else 0
		end as qtdItensConferencia,

		case when statusCodigoItem = 4 and tipoRm <> 0
			 then 1
			 else 0
		end as qtdItensEmdivergencia,

		case when statusCodigoItem = 5 and tipoRm <> 0
			 then 1
			 else 0
		end as qtdItensNoProcesso,

		case when statusCodigoItem = 6 and tipoRm <> 0
			 then 1
			 else 0
		end as qtdItensOk,

		case when statusCodigoItem = 7 and tipoRm <> 0
			 then 1
			 else 0
		end as qtdItensNaoAtendidoConferencia,

		case when statusCodigoItem = 8 and tipoRm <> 0
			 then 1
			 else 0
		end as qtdItensParcialConferidos
	INTO #ItensProduto
	FROM #Itens a 
		LEFT JOIN #Produto b on a.codigo = b.codigo and a.codigoEmpresa = b.codigoEmpresa 
	WHERE
		statusCodigoDocumento IN (SELECT valor from #STADOCUMENTO) AND 
		statusCodigoItem IN (SELECT valor from #STAITEM) 

	-- select top 1 * from #ItensProduto

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

	IF OBJECT_ID ('tempdb.dbo.#MovimentosInternos') is not null
		DROP TABLE #MovimentosInternos;

	SELECT 
		* 
	INTO #MovimentosInternos 
	FROM #ItensProduto

	UNION 
	SELECT 
		* 
	FROM #AcoesDocumento

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Tabela final

	SELECT 
		*, 
		(select count(codigo) from #MovimentosInternos B where A.documento = B.documento and A.codigoEmpresa = B.codigoEmpresa and codigo <> '') as qtdItens,
		(select count(codigo) from #MovimentosInternos B where codigo <> '') as qtdTotalDeItens,
		case when acao = 'Envio Separacao'
			then 'Esperando Impressao'
			else 
				case when acao = 'Impressao Sep'
					then 'Seprando'
					else 
						case when acao = 'Ok Separacao'
							then 'Esperando Conferencia'
							else 
								case when acao = 'Ok Conferencia(D)'
									then 'Esperando Verifcar (D)'
									else acao
								end
						end
				end
		end as acao2

	FROM #MovimentosInternos A
	WHERE 
		documento IN (select documento from #ItensProduto)
	ORDER BY 
		documento, idLogAcao ,item
END