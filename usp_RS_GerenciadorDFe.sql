/*
====================================================================================================================================================================================
Script do Report Server					Gerenciador DF-e
====================================================================================================================================================================================
										Histórico de alterações
====================================================================================================================================================================================
Data		Por							Descrição
**********	********************		********************************************************************************************************************************************
05/07/2024	ANDERSON WILLIAM			- Inclusão de novos campo NEECONF, NEEDIVST, NEEDIVCOM, NEEVALCALST, NEEOBS
										- Formatação do NEECGCCPF usando as funções específicas do BD;

20/02/2024	ANDERSON WILLIAM			- Conversão para Stored procedure
										- Uso de querys dinâmicas utilizando a "sp_executesql" para executar comando sql com parâmetros
										- Uso da "usp_GetCodigoEmpresaTabela" em vez de "sp_GetCodigoEmpresaTabela", 
										  SQL deixa de verificar SP no BD Master, buscando direto no SIBD
										- Inclusão de filtro pela empresa da tabela, irá atender empresas como ex.: MRE Ferramentas										
										- Uso da função "fSplit" para transformar os filtros multi-valores em tabelas, para facilitar condições via cláusula "IN()"
************************************************************************************************************************************************************************************
*/
alter proc [dbo].usp_RS_GerenciadorDFe(
--create proc [dbo].usp_RS_GerenciadorDFe(
	@empcod smallint,
	@emissaoDe datetime = null,
	@emissaoAte datetime = null,
	@efetivacaoDe datetime = null,
	@efetivacaoAte datetime = null,
	@dataConsulta datetime = null,
	@numeroNF decimal(10,0) = 0,
	@serie char(3) = '',
	@valorNfDe money = 0,
	@valorNfAte money = 0,
	@chaveAcesso char(44) = '',
	@cpfCnpj char(14) = '',
	@razaoSocial varchar(60) = '',
	@comEntrada varchar(10) = '',
	@entradaEfetivada varchar(10) = '',
	@situacaoNF varchar(200) = '',	
	@tipoOperacao varchar(200) = '',
	@conffiscal varchar(10),
	@divcompras varchar(10),
	@divst varchar(10)
	)
As Begin
	
	SET NOCOUNT ON;
----------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Declarações das variaveis locais
	DECLARE	@empresaTBS099 smallint,
			@Query nvarchar (MAX), @ParmDef nvarchar (500), @empresa smallint,

			@NEEDATEMI_DE datetime, @NEEDATEMI_ATE datetime, @NEEDATENT_DE datetime, @NEEDATENT_ATE datetime, @NEEDATCON datetime,
			@NEENUM decimal(10,0), @NEESERDOC char(3), @NEEVALTOT_DE money, @NEEVALTOT_ATE money,
			@NEECHAACE char(44), @NEECGCCPF char(14), @NEENOM varchar(60),
			@NEENFEENT varchar(10), @NEENFEEFE varchar(10),
			@situacoesNF varchar(200), @tiposOperacoes varchar(200), @NEECONF varchar(10), @NEEDIVCOM varchar(10), @NEEDIVST varchar(10)

	-- Atribuições das variaveis internas
	SET @empresa = @empcod
	SET @NEEDATEMI_DE = (Select ISNULL(@emissaoDe, '17530101'))
	SET @NEEDATEMI_ATE = (Select ISNULL(@emissaoAte, GETDATE()))
	SET @NEEDATENT_DE = (Select ISNULL(@efetivacaoDe, '17530101'))
	SET @NEEDATENT_ATE = (Select ISNULL(@efetivacaoAte, GETDATE()))
	SET @NEEDATCON = (Select ISNULL(@dataConsulta, '17530101 00:00:00'))
	SET @NEENUM = @numeroNF
	SET @NEESERDOC = @serie
	SET @NEEVALTOT_DE = @valorNfDe
	SET @NEEVALTOT_ATE = IIf(@valorNfAte = 0, 999999999, @valorNfAte)
	SET @NEECHAACE = @chaveAcesso
	SET @NEECGCCPF = @cpfCnpj
	SET @NEENOM = RTRIM(LTRIM(UPPER(@razaoSocial)))

	SET @NEENFEENT = @comEntrada
	SET @NEENFEEFE = @entradaEfetivada
	SET @situacoesNF = @situacaoNF
	SET @tiposOperacoes = @tipoOperacao
	SET @NEECONF = @conffiscal
	SET @NEEDIVCOM = @divcompras
	SET @NEEDIVST = @divst

	-- Verificar se a tabela é compartilhada ou exclusiva(Usando a SP com prefixo renomeada para "usp_...")
	EXEC dbo.usp_GetCodigoEmpresaTabela @empresa, 'TBS099', @empresaTBS099 output;

	-- Parametros multi valores Texto

	-- Com entrada: SIM/NAO
	If object_id('TempDB.dbo.#COMENTRADA') is not null
		DROP TABLE #COMENTRADA

    select elemento as [simnao]
	Into #COMENTRADA
    From fSplit(@NEENFEENT, ',')

-- Com Efetivacao: SIM/NAO
	If object_id('TempDB.dbo.#EFETIVADA') is not null
		DROP TABLE #EFETIVADA

    select elemento as [simnao]
	Into #EFETIVADA
    From fSplit(@NEENFEEFE, ',')

-- Com Div.fiscal: SIM/NAO
	If object_id('TempDB.dbo.#DIVFISCAL') is not null
		DROP TABLE #DIVFISCAL

    select elemento as [simnao]
	Into #DIVFISCAL
    From fSplit(@NEECONF, ',')

-- Com Div.compras: SIM/NAO
	If object_id('TempDB.dbo.#DIVCOMPRAS') is not null
		DROP TABLE #DIVCOMPRAS

    select elemento as [simnao]
	Into #DIVCOMPRAS
    From fSplit(@NEEDIVCOM, ',')

-- Com Div.compras: SIM/NAO
	If object_id('TempDB.dbo.#DIVST') is not null
		DROP TABLE #DIVST

    select elemento as [simnao]
	Into #DIVST
    From fSplit(@NEEDIVST, ',')
----------------------------------------------------------------------------------------------------------------------------------------------------------------

	If object_id('TempDB.dbo.#TBS099') is not null
		DROP TABLE #TBS099

	SELECT TOP 0
	NEESITNFE,
	NEENFEENT,
	NEENFEEFE,
	NEEDATEMI, 
	IIF(LEN(NEECGCCPF) = 14, dbo.FormatarCnpj(NEECGCCPF), dbo.FormatarCpf(NEECGCCPF)) as NEECGCCPF,	
	NEENOM, 
	NEENUM,
	NEESERDOC,
	NEEVALTOT,
	NEECHAACE, 
	NEEDATCON,
	NEECONF,
	NEEDIVCOM,
	NEEDIVST,
	NEEVALICMSST,
	NEEVALCALST,
	NEEOBS
	
	INTO #TBS099

	FROM TBS099 (NOLOCK)

	-- Query dinamica
	SET @Query	= N'
	INSERT INTO #TBS099

	SELECT 
	NEESITNFE,
	NEENFEENT,
	NEENFEEFE,
	NEEDATEMI, 
	IIF(LEN(NEECGCCPF) = 14, dbo.FormatarCnpj(NEECGCCPF), dbo.FormatarCpf(NEECGCCPF)) as NEECGCCPF,	
	NEENOM, 
	NEENUM,
	NEESERDOC,
	NEEVALTOT,
	NEECHAACE, 
	NEEDATCON,
	NEECONF,
	NEEDIVCOM,
	NEEDIVST,
	NEEVALICMSST,
	NEEVALCALST,
	NEEOBS

	FROM TBS099 (NOLOCK) 

	WHERE
	NEEEMPCOD = @empresaTBS099 AND
	convert(date, NEEDATEMI) BETWEEN @NEEDATEMI_DE AND @NEEDATEMI_ATE AND
	convert(date, NEEDATENT) BETWEEN @NEEDATENT_DE AND @NEEDATENT_ATE AND
	NEEVALTOT BETWEEN @NEEVALTOT_DE AND @NEEVALTOT_ATE AND
	NEEDATCON >= @NEEDATCON AND
	NEENFEENT COLLATE DATABASE_DEFAULT IN (SELECT simnao from #COMENTRADA) AND
	NEENFEEFE COLLATE DATABASE_DEFAULT IN (SELECT simnao from #EFETIVADA) AND
	NEECONF COLLATE DATABASE_DEFAULT IN (SELECT simnao from #DIVFISCAL) AND
	NEEDIVCOM COLLATE DATABASE_DEFAULT IN (SELECT simnao from #DIVCOMPRAS) AND	
	NEEDIVST COLLATE DATABASE_DEFAULT IN (SELECT simnao from #DIVST) AND
	NEESITNFE IN (' + @situacoesNF + ') AND
	NEETIPOPE IN (' + @tiposOperacoes + ')
	'
	+
	IIf(@NEENUM <= 0, '', ' AND NEENUM = @NEENUM')
	+
	IIf(@NEESERDOC = '', '', ' AND NEESERDOC = @NEESERDOC')
	+
	IIf(@NEENOM = '', '', ' AND NEENOM LIKE @NEENOM')
	+
	IIf(@NEECGCCPF = '', '', ' AND NEECGCCPF LIKE @NEECGCCPF')
	+
	IIf(@NEECHAACE = '', '', ' AND NEECHAACE = @NEECHAACE')

--SELECT @Query

	-- Executa a Query dinâminca(QD)
	SET @ParmDef = N'@empresaTBS099 smallint, @NEEDATEMI_DE datetime, @NEEDATEMI_ATE datetime,  @NEEDATENT_DE datetime, @NEEDATENT_ATE datetime, @NEEDATCON datetime,
					 @NEENUM decimal(10,0), @NEESERDOC char(3), @NEEVALTOT_DE money, @NEEVALTOT_ATE money,
					 @NEECHAACE char(44), @NEECGCCPF char(14), @NEENOM varchar(60)'


	EXEC sp_executesql @Query, @ParmDef, @empresaTBS099, @NEEDATEMI_DE, @NEEDATEMI_ATE,  @NEEDATENT_DE, @NEEDATENT_ATE, @NEEDATCON,
					   @NEENUM, @NEESERDOC, @NEEVALTOT_DE, @NEEVALTOT_ATE,
					   @NEECHAACE, @NEECGCCPF, @NEENOM
----------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Tabela final para ficar "visivel" os campos para o ReportServer
	SELECT * FROM #TBS099
----------------------------------------------------------------------------------------------------------------------------------------------------------------
End