/*
====================================================================================================================================================================================
WREL026 - Faturamento - Descontos - Devolucoes por vendedor
====================================================================================================================================================================================
Historico de alteracoes
====================================================================================================================================================================================
05/04/2025 WILLIAM
	- Inclusao do parametro de entrada [@ptipoDocumento = 'N'] na chamada da SP [AlimentaDWVendas], para processar apenas notas emitidas, ja que os cupons nao e usado no relatorio;
	- Alteracao para mostrar "<SEM VENDEDOR>" no campo VENNOM, quando nao tiver vendedor vinculado ao faturamento;
31/03/2025 WILLIAM
	- Correcao ao registrar a devolucao da venda por documento;
27/03/2025 WILLIAM
	- Uso das SPs "usp_Get_DWVendas" e "usp_Get_DWDevolucaoVendas", para obter as informacoes vendas e devolucao;
	- Utilizacao da tecnica CTE, para agrupar as vendas e devolucoes conforme para a loja, corporativo e grupo BMPT;
	- Retirada de codigo sem uso;
30/01/2025 WILLIAM
	- Aplicar refinamento no codigo;
	- Uso da SP "usp_Get_CodigosVendedores" e "usp_Get_CodigosClientes";
	- Uso da funcao "ufn_Get_TemFrenteLoja", para saber se empresa tem frente de loja;
	- Uso da funcao "ufn_Get_Parametro", para obter valor do parametro 1330;
	- Udo da SP "usp_GetCodigoEmpresaTabela", para obter a empresa da tabela caso seja exclusiva ou compartilhada;
	- Inclusao de filtro pela data de/ate na tabela TBS080, notas autorizadas. *** Vamos fazer testes *** ;
13/12/2024 WILLIAM
	- Inclusao do @empcod nos parametros de entrada da SP;
	- Alteracao nos parametros da chamada da SP "usp_ClientesGrupo", passando o codigo da empresa @empresa;
====================================================================================================================================================================================
*/
--ALTER PROC [dbo].[usp_RS_FaturamentoDescontoDevolucaoVendedor_DEBUG]
ALTER PROC [dbo].[usp_RS_FaturamentoDescontoDevolucaoVendedor] 
	@empcod smallint,
	@dataDe date, 
	@dataAte date, 
	@codigoVendedor varchar(200) = '', 
	@nomeVendedor varchar(60) = '',
	@pGrupoBMPT char(1) = 'S'
AS
BEGIN
	SET NOCOUNT ON;
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	DECLARE @codigoEmpresa smallint, @data_De date, @data_Ate date, @VENCOD varchar(500), @VENNOM varchar(30), @GrupoBMPT char(1),
			@contabiliza char(10);
			 
-- Desativando a detecao de parametros(Parameter Sniffing)
	SET @codigoEmpresa = @empcod;	
	SET @data_De = (SELECT ISNULL(@dataDe, '17530101'));
	SET @data_Ate = (SELECT ISNULL(@dataAte, GETDATE() - 1));
	SET @VENCOD = @codigoVendedor;
	SET @VENNOM = @nomeVendedor;
	SET @GrupoBMPT = UPPER(@pGrupoBMPT);

-- Atribuicoes internas
	-- Verifica se usuario escolheu para contabilizar vendas das empresas do grupo ou nao, para passar para a SP: C:corporativo;L-loja;G-grupo BMPT
	SET @contabiliza = IIF(@GrupoBMPT = 'N', 'C,L', '');		

/***********************************************************************************************************************************************************************************
	Obter as vendas da tabela DWVendas
***********************************************************************************************************************************************************************************/	
	-- Com as vendas obtidas via tabela temporaria ##DWVendas criada pela SP, conseguimos separar as vendas do grupo, loja e corporativo

	EXEC usp_Get_DWVendas
		@empcod = @codigoEmpresa,
		@pdataDe = @data_De,
		@pdataAte = @data_Ate,
		@pcodigoVendedor = @VENCOD,
		@pnomeVendedor = @VENNOM,
		@pcontabiliza = @contabiliza,
		@ptipoDocumento = 'N'

--	 SELECT * FROM ##DWVendas;

/***********************************************************************************************************************************************************************************
	Obter as devolucoes da tabela DWDevolucaoVendas
***********************************************************************************************************************************************************************************/	
	-- Com as devolucoes obtidas via tabela temporaria ##DWDevolucaoVendas criada pela SP, conseguimos separar as vendas do grupo, loja e corporativo

	EXEC usp_Get_DWDevolucaoVendas
		@empcod = @codigoEmpresa,
		@pdataDe = @data_De,
		@pdataAte = @data_Ate,
		@pcodigoVendedor = @VENCOD,
		@pnomeVendedor = @VENNOM,
		@pcontabiliza = @contabiliza

 --SELECT * FROM ##DWDevolucaoVendas;
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Utilizaremos CTE para obter informacao da tabela de METAS, e contabilizar as vendas e devolucoes por vendedor;

	;WITH
		-- Vendas agrupadas por vendedor, cliente e numero de documento
		vendas_agrupadas AS(		
		SELECT		
			codigoVendedor,
			nomeVendedor,
			codigoCliente,
			nomeCliente,
			numeroDocumento,
			CONVERT(CHAR(12), data, 103) AS DATA,
			CONVERT(CHAR(12), data, 111) AS DATA2,
			numeroSerieDocumento,
			IIF(documentoReferenciado = '', 'N', 'L') AS NFSTIP,	-- Se tem documento referenciado, e nota de cupom, registra como 'L'oja
			SUM(valorTotal) AS valorTotal,
			sum(valorDescontoTotal) AS valorDescontoTotal	
		FROM ##DWVendas
		
		WHERE		
			numeroSerieDocumento > 0	-- Contabilizar somente o que foi emitido nota(faturado)

		GROUP by 
			codigoVendedor,
			nomeVendedor,
			codigoCliente,
			nomeCliente,
			numeroDocumento,
			data,
			numeroSerieDocumento,
			documentoReferenciado				
		),
		-- Devolucoes agrupadas por vendedor, cliente e numero de documento
		devolucaoes_agrupadas AS(		
		SELECT		
			codigoVendedor,
			nomeVendedor,
			codigoCliente,
			nomeCliente,
			numeroDocumento,
			CONVERT(CHAR(12), data, 103) AS DATA,
			CONVERT(CHAR(12), data, 111) AS DATA2,
			numeroSerieDocumento,
			numeroDocumentoAuxiliar,
			serieDocumentoAuxiliar,			
			'D' AS NFSTIP,			
			SUM(valorTotal) AS valorTotal
		FROM ##DWDevolucaoVendas
		
		GROUP by 
			codigoVendedor,
			nomeVendedor,
			codigoCliente,
			nomeCliente,
			numeroDocumento,
			data,
			numeroSerieDocumento,
			numeroDocumentoAuxiliar,
			serieDocumentoAuxiliar		
		),
		-- Junta os dados de vendas e devolucoes em uma tabela so
		vendas_devolucoes AS(			
		SELECT 
			IIF(ISNULL(V.NFSTIP, '') <> '', 1, 0 ) AS NFS,
			ISNULL(V.codigoVendedor, D.codigoVendedor) AS VENCOD,
			ISNULL(V.nomeVendedor, D.nomeVendedor) AS VENNOM,
			ISNULL(V.codigoCliente, D.codigoCliente) AS NFSCLICOD,
			ISNULL(V.nomeCliente, D.nomeCliente) AS NFSCLINOM,
			ISNULL(V.DATA, D.DATA) AS DATA,
			ISNULL(V.DATA2, D.DATA2) AS DATA2,			
			ISNULL(V.numeroDocumento, D.numeroDocumento) AS NFSNUM,			
			ISNULL(V.numeroSerieDocumento, D.numeroSerieDocumento) AS SNESER,
			ISNULL(V.NFSTIP, D.NFSTIP) AS NFSTIP,
			ISNULL(V.valorTotal, 0) AS NFSTOTLIQ,
			ISNULL(V.valorDescontoTotal, 0) AS NFSVDDTOT,			
			ISNULL(D.valorTotal, 0) AS NFSTOTDEV
		FROM vendas_agrupadas V
			FULL JOIN devolucaoes_agrupadas D ON
				V.codigoVendedor = D.codigoVendedor AND
				V.codigoCliente = D.codigoCliente AND
				V.numeroDocumento = numeroDocumentoAuxiliar AND
				V.numeroSerieDocumento = serieDocumentoAuxiliar 
				--V.DATA = D.DATA
		)		
		-- Tabela final
		SELECT 
			NFS,
			VENCOD,
			IIF(RTRIM(LTRIM(VENNOM)) = '', '<SEM VENDEDOR>', RTRIM(LTRIM(VENNOM))) AS VENNOM,
			NFSCLICOD,
			NFSCLINOM,
			DATA,
			DATA2,			
			NFSNUM,			
			SNESER,
			NFSTIP,
			NFSTOTLIQ,
			NFSVDDTOT,			
			NFSTOTDEV
			-- *
		FROM vendas_devolucoes

		ORDER BY
			VENCOD,
			DATA2,
			NFSNUM,
			NFSCLICOD

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Apaga as temporarias globais

	DROP TABLE ##DWVendas;
	DROP TABLE ##DWDevolucaoVendas;

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
END