/*
====================================================================================================================================================================================
WREL033 - Movimentacoes do Produto nos Estoques
====================================================================================================================================================================================
Histórico de alterações
====================================================================================================================================================================================
16/04/2026 WILLIAM
	- Incluscao da clausula "COLLATE DATABASE_DEFAULT" no momente de criar as tabelas [#TBS010] e [#ROTMOV] e, melhora a performance sem estar no "Where";
	- Troca da clausula "IN" pela "EXISTS", no filtro da tabela #TBS051, melhora a performance ja que a "EXISTS" para de pesquisar na subconsulta assim que encontra
	o primeiro registro correspondente;
	- Inclusao do registro ['PVEN137' , 'VIA PEDIDO VENDA RAPIDA'];
27/01/2025 WILLIAM
	- Aplicar refinamento no codigo;
	- Utilizacao da SP "usp_GetCodigosProdutos";
03/09/2024	WILLIAM
	- Melhoria em mostrar a movimentação de baixar e cancelamento de cupom, antes aparecia como "BAIXA CUPOM" mesmo quando o movimento foi de 
	cancelamento de cupom, confundindo o usuário(a);
06/02/2024	WILLIAM
	- Alteracao do tipo dos parametros que estao em "Combobox" para varchar(), para serem incluidos nas Query dinamicas
05/02/2024	WILLIAM			
	- Conversao para Stored procedure
31/01/2023	WILLIAM
	- Uso de querys dinamicas utilizando a "sp_executesql" para executar comando sql com parametros
	- Uso da "usp_GetCodigoEmpresaTabela" em vez de "sp_GetCodigoEmpresaTabela",  SQL deixa de verificar SP no BD Master, buscando direto no SIBD
	- Inclusao de filtro pela empresa da tabela, ira atender empresas como ex.: MRE Ferramentas
====================================================================================================================================================================================
*/
--create proc [dbo].[usp_RS_MovimentacaoProdutoEstoques]
ALTER PROC [dbo].[usp_RS_MovimentacaoProdutoEstoques]
	@empcod int,
	@DATADE datetime, 
	@DATEATE datetime = NULL,
	@PROCOD varchar(8000),
	@MARCOD int = 0,
	@LMEACA varchar(20),
	@LMEINFALT varchar(20),
	@LMELOCEST varchar(80),	
	@LMEDOC int = 0
AS
BEGIN
	SET NOCOUNT ON;
------------------------------------------------------------------------------------------------------------------------------------------------------------	
	DECLARE @codigoEmpresa smallint, @empresaTBS010 smallint,  @empresaTBS033 smallint, @empresaTBS034 smallint, @empresaTBS037 smallint, @empresaTBS051 smallint,
			@codigo varchar(8000), @dataHoraDe datetime, @dataHoraAte datetime, @CodMarca int, @LocaisEst varchar(80), @Documento int,
			@acao varchar(20), @infalt varchar(20),
			@Query nvarchar (MAX), @ParmDef nvarchar (500)

-- Desativando a detecção de parâmetros(Parameter Sniffing)
	SET @codigoEmpresa = @empcod;
	SET @dataHoraDe = @DATADE;
	SET @dataHoraAte = (select case when @DATEATE is null then dateadd(second, -1, convert(datetime,convert(date,getdate() +1))) else dateadd(second, -1, convert(datetime,convert(date,dateadd(day, 1, @DATEATE)))) end )
	SET @codigo = @PROCOD;
	SET @CodMarca = @MARCOD;
	SET @LocaisEst = @LMELOCEST;
	SET @acao = replace(replace(@LMEACA, ',', ''','''), ' ','')
	SET @infalt = replace(replace(@LMEINFALT, ',', ''','''), ' ','')
	SET @Documento = (SELECT ISNULL(@LMEDOC, 0));	

-- Verificar se a tabela e compartilhada ou exclusiva
	EXEC dbo.usp_GetCodigoEmpresaTabela @codigoEmpresa, 'TBS010', @empresaTBS010 output;
	EXEC dbo.usp_GetCodigoEmpresaTabela @codigoEmpresa, 'TBS033', @empresaTBS033 output;
	EXEC dbo.usp_GetCodigoEmpresaTabela @codigoEmpresa, 'TBS034', @empresaTBS034 output;
	EXEC dbo.usp_GetCodigoEmpresaTabela @codigoEmpresa, 'TBS037', @empresaTBS037 output;
	EXEC dbo.usp_GetCodigoEmpresaTabela @codigoEmpresa, 'TBS051', @empresaTBS051 output;
	
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Filtra produto pelo código ou código de barras, se vazio filtra todos os código da TBS010, via SP

	If OBJECT_ID ('tempdb.dbo.#TBS010') IS NOT NULL
		DROP TABLE #TBS010;

	CREATE TABLE #TBS010(
		PROCOD VARCHAR(15) COLLATE DATABASE_DEFAULT
	)

	INSERT INTO #TBS010
	EXEC usp_GetCodigosProdutos @codigoEmpresa, @codigo, '', @CodMarca, ''
	
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Descricao dos movimentos de transferencia, entrada ou saida forcada

	If object_id('tempdb.dbo.#TBS037') IS NOT NULL 
		DROP TABLE #TBS037;

	SELECT 
		MVIDOC, 
		A.TMVCOD,
		CASE WHEN A.TMVCOD < 500 AND B.TMVDES = 'PARA RESERVA DE PEDIDOS VENDAS' 
			THEN 'ENTRADA FORCADA, RESERVA PDV (' + RTRIM(LTRIM(MVIPDVNUM)) + ')'
			ELSE 
				CASE WHEN A.TMVCOD > 500 AND B.TMVDES = 'PARA RESERVA DE PEDIDOS VENDAS' 
					THEN 'TRANSFERENCIA, RESERVA PDV (' + RTRIM(LTRIM(MVIPDVNUM)) + ')'
					ELSE RTRIM(LTRIM(B.TMVDES)) + ' VIA MOV INTERNO' 
				END
		END AS TMVDES,
		A.MVITRM
	INTO #TBS037 FROM TBS037 A (NOLOCK) 
		LEFT JOIN TBS033 B (NOLOCK) ON B.TMVEMPCOD = @empresaTBS033 AND A.TMVCOD = B.TMVCOD

	WHERE 
		MVIEMPCOD = @empresaTBS037 AND
		((A.MVIDATEFE BETWEEN @dataHoraDe AND @dataHoraAte) OR (A.MVIDATLAN BETWEEN @dataHoraDe AND @dataHoraAte))

	ORDER BY 
		A.MVIEMPCOD,
		A.MVIDATEFE, 
		A.MVIDATLAN

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Obtem apenas o codigo do registro do movimento

	IF object_id('tempdb.dbo.#REGISTROS') IS NOT NULL 	
		DROP TABLE #REGISTROS;

	SELECT 
		LMEREG
	INTO #REGISTROS FROM TBS051 a WITH (NOLOCK)
	WHERE
		LMEEMPCOD = @empresaTBS051 
		AND LMEDATHOR BETWEEN @dataHoraDe AND @dataHoraAte
		AND EXISTS(SELECT PROCOD FROM #TBS010 b WHERE b.PROCOD = a.PROCOD)
	ORDER BY
		LMEEMPCOD,
		LMEREG,
		LMEDATHOR

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Faz o refinamento dos movimentos

	IF object_id('tempdb.dbo.#TBS051') IS NOT NULL 	
		DROP TABLE #TBS051;
	
	-- "SELECT TOP 0" para criar a estrutura da tabela antes de executar a query dinamica
	SELECT TOP 0
		LMEREG,
		LMEDATHOR,
		LMEDOC,
		PROCOD, 
		LMEACA,
		LMEINFALT,
		LMEUNI,
		LESDES,
		LMEQTDMOV,
		LMEQTDSAL, 
		LMEUSU,
		LMEDESROT,
		LMEQTDCMP,
		LMEQTDPEN,
		LMEQTDATU,
		LMEQTDRES,
		LMEROT,
		LMELOCEST,
		LMEHOST, 
		LMEIP,
		LMECUPCXA,
		LMECUPDAT,
		LMECUPHOR
	INTO #TBS051 FROM TBS051 A (NOLOCK) 
		LEFT JOIN TBS034 B (NOLOCK) ON A.LMELOCEST = B.LESCOD AND B.LESEMPCOD = @empresaTBS034

	-- Monta Query para popular a temporaria #TBS051
	Set @Query = N'
	INSERT INTO #TBS051
	
	SELECT 
		LMEREG,
		LMEDATHOR,
		LMEDOC,
		PROCOD, 
		LMEACA,
		LMEINFALT,
		LMEUNI,
		LESDES,
		LMEQTDMOV,
		LMEQTDSAL, 
		LMEUSU,
		LMEDESROT,
		LMEQTDCMP,
		LMEQTDPEN,
		LMEQTDATU,
		LMEQTDRES,
		LMEROT,
		LMELOCEST,
		LMEHOST, 
		LMEIP,
		LMECUPCXA,
		LMECUPDAT,
		LMECUPHOR
	FROM TBS051 A (NOLOCK) 	
		LEFT JOIN TBS034 B (NOLOCK) ON A.LMELOCEST = B.LESCOD AND B.LESEMPCOD = @empresaTBS034

	WHERE
		LMEEMPCOD	= @empresaTBS051 AND 
		LMEREG		IN (select LMEREG from #REGISTROS) AND
		LMEACA		IN (''' + rtrim(ltrim(@acao)) + ''') AND
		LMEINFALT	IN (''' + rtrim(ltrim(@infalt)) + ''') AND
		LMELOCEST	IN (' + @LocaisEst + ')
	'
	+
	IIF(@Documento = 0, '', ' AND LMEDOC = @Documento')

	Set @Query += '
	ORDER BY 
	LMEEMPCOD,
	LMEREG desc		
	'	
	-- Executa a Query dinAminca(QD)
	SET @ParmDef = N'@empresaTBS034 int, @empresaTBS051 int, @Documento int'

	EXEC sp_executesql @Query, @ParmDef, @empresaTBS034, @empresaTBS051, @Documento
	
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Criar tabela de descricao do movimento

	IF OBJECT_ID('TEMPDB.DBO.#ROTMOV') IS NOT NULL 
		DROP TABLE #ROTMOV;

	CREATE TABLE #ROTMOV(
		LMEROT VARCHAR (8) COLLATE DATABASE_DEFAULT,
		LMEDESROT VARCHAR(30) COLLATE DATABASE_DEFAULT
	);

	INSERT INTO #ROTMOV ( LMEROT, LMEDESROT) VALUES ('PCOM009' , '')
	INSERT INTO #ROTMOV ( LMEROT, LMEDESROT) VALUES ('PCOM167' , '')
	INSERT INTO #ROTMOV ( LMEROT, LMEDESROT) VALUES ('PCOM023' , 'PDC VIA SUGESTAO COMPRA')
	INSERT INTO #ROTMOV ( LMEROT, LMEDESROT) VALUES ('PCOM035' , 'IMPORTACAO DE PRODUTO')
	INSERT INTO #ROTMOV ( LMEROT, LMEDESROT) VALUES ('PCOM051' , 'SOLICITACAO DE COMPRA')
	INSERT INTO #ROTMOV ( LMEROT, LMEDESROT) VALUES ('PCOM165' , 'SOLICITACAO DE COMPRA')
	INSERT INTO #ROTMOV ( LMEROT, LMEDESROT) VALUES ('PCOM055' , 'MOV. INTERNO VIA SDC')
	INSERT INTO #ROTMOV ( LMEROT, LMEDESROT) VALUES ('PCOM058' , 'CANCELAMENTO SDC')
	INSERT INTO #ROTMOV ( LMEROT, LMEDESROT) VALUES ('PCOM059' , 'ESTORNO RESERVA SDC')
	INSERT INTO #ROTMOV ( LMEROT, LMEDESROT) VALUES ('PCOM113' , 'NF DEV. PARA FORNECEDOR')
	-- INSERT INTO #ROTMOV ( LMEROT, LMEDESROT) VALUES ('PEST005' , 'MOV.INTE VIA MAN.SALDO') -- 
	INSERT INTO #ROTMOV ( LMEROT, LMEDESROT) VALUES ('PEST008' , 'ITEM EXCLUIDO MOV.INT')
	INSERT INTO #ROTMOV ( LMEROT, LMEDESROT) VALUES ('PEST010' , 'GERA SALDO PRODUTO')
	INSERT INTO #ROTMOV ( LMEROT, LMEDESROT) VALUES ('PEST015' , 'EFETIVACAO MOV.INT')
	INSERT INTO #ROTMOV ( LMEROT, LMEDESROT) VALUES ('PEST022' , 'ENTRADA NOTA FISCAL')
	INSERT INTO #ROTMOV ( LMEROT, LMEDESROT) VALUES ('PEST029' , 'RESERVA MANUAL')
	INSERT INTO #ROTMOV ( LMEROT, LMEDESROT) VALUES ('PEST030' , 'RESERVA AUTOMATICA')
	INSERT INTO #ROTMOV ( LMEROT, LMEDESROT) VALUES ('PEST053' , 'CADASTRO DE PRODUTO')
	INSERT INTO #ROTMOV ( LMEROT, LMEDESROT) VALUES ('PEST071' , 'MANUTENCAO DE SALDOS')
	-- INSERT INTO #ROTMOV ( LMEROT, LMEDESROT) VALUES ('PEST149' , 'ENTRADA DIRETO PARA PDV') -- 
	INSERT INTO #ROTMOV ( LMEROT, LMEDESROT) VALUES ('PMSL033' , 'BAIXA CUPOM FISCAL')
	INSERT INTO #ROTMOV ( LMEROT, LMEDESROT) VALUES ('PMSL065' , 'BAIXA CUPOM FISCAL')
	INSERT INTO #ROTMOV ( LMEROT, LMEDESROT) VALUES ('PVEN004' , 'ITEM INSERIDO PED.VEN')		
	INSERT INTO #ROTMOV ( LMEROT, LMEDESROT) VALUES ('PVEN016' , 'ITEM EXCLUIDO PED.VEN')
	INSERT INTO #ROTMOV ( LMEROT, LMEDESROT) VALUES ('PVEN031' , 'NOTA FISCAL SAIDA C.A' )
	INSERT INTO #ROTMOV ( LMEROT, LMEDESROT) VALUES ('PVEN032' , 'ESTORNO RESERVA PDV')
	INSERT INTO #ROTMOV ( LMEROT, LMEDESROT) VALUES ('PVEN034' , 'CANCELA PEDIDO VENDA')
	INSERT INTO #ROTMOV ( LMEROT, LMEDESROT) VALUES ('PVEN040' , 'CANCELA NF SAIDA')
	INSERT INTO #ROTMOV ( LMEROT, LMEDESROT) VALUES ('PVEN044' , 'NOTA FISCAL SAIDA S.A')
	INSERT INTO #ROTMOV ( LMEROT, LMEDESROT) VALUES ('SQL' , '')
	INSERT INTO #ROTMOV ( LMEROT, LMEDESROT) VALUES ('PEST172' , 'NOTA FISCAL TRANS AUTO')
	INSERT INTO #ROTMOV ( LMEROT, LMEDESROT) VALUES ('CSHARP' , 'BAIXA CUPOM FISCAL')
	INSERT INTO #ROTMOV ( LMEROT, LMEDESROT) VALUES ('PCOM144' , 'GERA SALDO INICIAL - IMP')
	INSERT INTO #ROTMOV ( LMEROT, LMEDESROT) VALUES ('APP04-1' , 'APLICATIVO RM')
	INSERT INTO #ROTMOV ( LMEROT, LMEDESROT) VALUES ('PEST205' , 'MOV.INTERNO DE USO E CONSUMO')
	INSERT INTO #ROTMOV ( LMEROT, LMEDESROT) VALUES ('PVEN137' , 'VIA PEDIDO VENDA RAPIDA')		

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- TABELA FINAL

	IF object_id('tempdb.dbo.#MOVIMENTACAOPRODUTO') IS NOT NULL
		DROP TABLE #MOVIMENTACAOPRODUTO;	

	SELECT 
		IDENTITY(int, 1, 1) AS RANK,
		LMEREG,
		LMEDATHOR,
		LMEDOC,
		PROCOD, 
		CASE WHEN LMEACA = 'E' AND LMEINFALT = 'C'
			THEN 'Entrou em'
			ELSE 
				CASE WHEN LMEACA = 'E' AND LMEINFALT = 'P'
					THEN 'Entrou na'
					ELSE 
						CASE WHEN LMEACA = 'E' AND LMEINFALT = 'E'
							THEN 'Entrou no'
							ELSE
								CASE WHEN LMEACA = 'E' AND LMEINFALT = 'R'
									THEN 'Entrou na'
									ELSE 
										CASE WHEN LMEACA = 'S' AND LMEINFALT = 'C'
											THEN 'Saiu do'
											ELSE
												CASE WHEN LMEACA = 'S' AND LMEINFALT = 'P'
													THEN 'Saiu da'
													ELSE 
														CASE WHEN LMEACA = 'S' AND LMEINFALT = 'E'
															THEN 'Saiu do'
															ELSE 
																CASE WHEN LMEACA = 'S' AND LMEINFALT = 'R'
																	THEN 'Saiu da'
																	ELSE ''
																END
														END
												END
										END
								END
						END
				END
		END AS MOVIMENTOU,
		CASE WHEN LMEACA = 'E'
			THEN 'ENTROU'
			ELSE 'SAIU'
		END AS LMEACA,
		CASE LMEINFALT 
			WHEN 'C' THEN 'Compras'
			WHEN 'P' THEN 'Pendencia'
			WHEN 'E' THEN 'Fisico'
			WHEN 'R' THEN 'Reserva'
		END AS LMEINFALT,	
		--LTRIM(RTRIM(STR(LMELOCEST))) + '-' + B.LESDES AS LMELOCEST, 
		LMELOCEST, 
		LMEUNI,
		CASE WHEN LMEACA = 'E' 
			THEN LMEQTDMOV
			ELSE 0
		END AS LMEQTDMOVENT,

		CASE WHEN LMEACA = 'S' 
			THEN LMEQTDMOV
			ELSE 0
		END AS LMEQTDMOVSAI,

		CASE LMEINFALT 
			WHEN 'C' THEN LMEQTDCMP
			WHEN 'P' THEN LMEQTDPEN
			WHEN 'E' THEN LMEQTDATU
			WHEN 'R' THEN LMEQTDRES
		END AS LMEQTD,
		LMEQTDSAL, 
		LMEUSU,

		CASE WHEN C.LMEDESROT IS NULL 
			THEN 
				CASE WHEN D.TMVDES IS NULL 
					THEN 
			 			CASE WHEN A.LMEROT = 'PEST005'
							THEN 'VIA MOV INTERNO'
							ELSE 'NAO CATALOGADO'
						END
					ELSE D.TMVDES
				END
			ELSE
				CASE WHEN C.LMEDESROT = '' AND (A.LMEROT = 'SQL' OR A.LMEROT = 'PCOM009' OR A.LMEROT = 'PCOM167')
					THEN rtrim(A.LMEDESROT)
					ELSE 
						IIF(A.LMEROT = 'CSHARP',  'CUPOM - ' + IIF(LMEACA = 'S', 'BAIXA', 'CANCELAMENTO'), rtrim(C.LMEDESROT))
				END
		END AS LMEDESROT,
		LMEHOST, 
		LMEIP,
		case when LMECUPCXA = 0 
			then ''
			else 'Caixa: ' + ltrim(str(LMECUPCXA)) + ' - ' + convert(char(8),LMECUPDAT, 3) + ' ' + LMECUPHOR
		end LMECUPCXA

	INTO #MOVIMENTACAOPRODUTO FROM #TBS051 A (NOLOCK) 
		LEFT JOIN TBS034 B (NOLOCK) ON A.LMELOCEST = B.LESCOD AND B.LESEMPCOD = @empresaTBS034
		LEFT JOIN #ROTMOV C ON A.LMEROT = C.LMEROT 
		LEFT JOIN #TBS037 D ON A.LMEDOC = D.MVIDOC AND A.LMEROT IN ('PEST149', 'PEST005')

--------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Tabela final

	-- PARA EFEITO DE PAGINA QUANDO CHEGAR AO MAXIMO DE LINHA OPR PAGINA NO EXCEL
	SELECT 
		CASE WHEN RANK <= 65520 
			THEN 1
			ELSE 
				CASE WHEN RANK BETWEEN 65521 AND 131041
					THEN 2
					ELSE 
						CASE WHEN RANK BETWEEN 131042 AND 196562
							THEN 3
							ELSE 
								CASE WHEN RANK BETWEEN 196563 AND 262083
									THEN 4
									ELSE
										CASE WHEN RANK BETWEEN 262084 AND 327604
											THEN 5
											ELSE 
												CASE WHEN RANK BETWEEN 327605 AND 393125
													THEN 6
													ELSE 
														CASE WHEN RANK BETWEEN 393126 AND 458646
															THEN 7
															ELSE 
																CASE WHEN RANK BETWEEN 458647 AND 524167
																	THEN 8 
																	ELSE 
																		CASE WHEN RANK BETWEEN 524168 AND 589668
																			THEN 9
																			ELSE 
																				CASE WHEN RANK BETWEEN 589669 AND 655189
																					THEN 10
																					ELSE 11
																				END
																		END
																END
														END
												END
										END
								END
						END
				END
		END AS PAG,
		* 
	FROM #MOVIMENTACAOPRODUTO
End