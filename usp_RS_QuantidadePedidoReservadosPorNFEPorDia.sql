/*
					****** Relatorio esta defazado, pois filtra apenas dados do caixa 6, quando antigamente só se passa compras do delivery *******
====================================================================================================================================================================================
WREL049 - Quantidade de pedido reservados por NFE agrupado por dia
====================================================================================================================================================================================
Historico de alteracoes
====================================================================================================================================================================================
20/01/2025 - WILLIAM	 
	- Inclusao do @empcod nos parametros de entrada da SP;
	- Conversao para stored procedute;
	- Inclusão de filtros nas tabelas pela empresa, utilizando o parâmetro recebido via menu do Integros(@empcod), juntamente com a SP "usp_GetCodigoEmpresaTabela";
************************************************************************************************************************************************************************************
*/
CREATE PROCEDURE [dbo].[usp_RS_QuantidadePedidoReservadosPorNFEPorDia]
	@empcod smallint,
	@datade datetime,
	@dataate datetime
AS
BEGIN
	SET NOCOUNT ON;
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	DECLARE @codigoEmpresa smallint, @empresaTBS059 smallint, @empresaTBS080 smallint,
			@data_De datetime, @data_Ate datetime;

	SET @codigoEmpresa = @empcod;
	SET @data_De = @datade;
	SET @data_Ate = @dataate;

-- Verificar se a tabela é compartilhada ou exclusiva			
	exec dbo.usp_GetCodigoEmpresaTabela @codigoEmpresa, 'TBS059', @empresaTBS059 output;
	exec dbo.usp_GetCodigoEmpresaTabela @codigoEmpresa, 'TBS080', @empresaTBS080 output;

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Tabela final

	SELECT 
		CONVERT(CHAR (10),C.NFEATEDAT,103) AS DIA,
		A.NFENUM,
		C.NFEPEDNUM,
		A.PROCOD,
		A.NFEDES,
		C.NFEATEQTD,
		A.NFEUNI,
		CASE B.NFECAN
			WHEN 'N' THEN 'NAO'
			WHEN '' THEN 'NAO'
			ELSE 'SIM'
		END AS NFECAN
	FROM TBS0591 A (NOLOCK)
		INNER JOIN TBS059  B (NOLOCK) ON A.NFEEMPCOD = B.NFEEMPCOD AND A.NFECOD = B.NFECOD AND A.NFENUM = B.NFENUM AND A.NFETIP = B.NFETIP AND A.SERCOD = B.SERCOD 
		INNER JOIN TBS0592 C (NOLOCK) ON A.NFEEMPCOD = C.NFEEMPCOD AND A.NFECOD = C.NFECOD AND A.NFENUM = C.NFENUM AND A.NFETIP = C.NFETIP AND A.SERCOD = C.SERCOD AND A.NFEITE = C.NFEITE
		LEFT JOIN  TBS080  D (NOLOCK) ON ENFEMPCOD = @empresaTBS080 AND A.NFENUM = D.ENFNUM       AND A.NFECOD = D.ENFCODDES
		
	WHERE 
		A.NFEEMPCOD = @empresaTBS059 AND
		B.NFEDATEFE BETWEEN @data_De AND @data_Ate AND 
		((D.ENFSIT = 6 AND D.ENFFINEMI = 4 AND D.ENFTIPDOC = 0) OR ((NFENOSFOR = 'N' OR NFENOSFOR = '') AND /*(B.NFECAN = 'N' OR B.NFECAN = '') AND */NFEDATEFE <> '' )) AND
	NFETIPPED = 'V'
END
