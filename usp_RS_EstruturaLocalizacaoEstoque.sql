/*
====================================================================================================================================================================================
WREL119 - Estrutura de localização no estoque
====================================================================================================================================================================================
Histórico de alterações
====================================================================================================================================================================================
14/01/2025 - WILLIAM
	- Conversão do script SQL para StoredProcedure;
	- Inclusão do @empcod nos parâmetros de entrada da SP;	
	- Inclusão de filtros nas tabelas pela empresa, utilizando o parâmetro recebido via menu do Integros(@empcod), juntamente com a SP "usp_GetCodigoEmpresaTabela";
************************************************************************************************************************************************************************************
*/
CREATE PROCEDURE [dbo].[usp_RS_EstruturaLocalizacaoEstoque]
--alter PROCEDURE [dbo].[usp_RS_EstruturaLocalizacaoEstoque]
	@empcod smallint,
	@rua varchar(10),
	@bloco varchar(10),
	@andar varchar(10),
	@apto varchar(10)
AS
BEGIN
	SET NOCOUNT ON;
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	DECLARE @codigoEmpresa smallint, @empresaTBS010 smallint, @empresaTBS032 smallint,
			@cRua varchar(10), @cBloco varchar(10), @cAndar varchar(10),@cApto varchar(10);

-- Desativando a detecção de parâmetros(Parameter Sniffing)
	SET @codigoEmpresa = @empcod;
	SET @cRua = @rua;
	SET @cBloco = @bloco;
	SET @cAndar = @andar;
	SET @cApto = @apto;

-- Verificar se a tabela compartilhada ou exclusiva
	EXEC dbo.usp_GetCodigoEmpresaTabela @codigoEmpresa, 'TBS010', @empresaTBS010 output;
	EXEC dbo.usp_GetCodigoEmpresaTabela @codigoEmpresa, 'TBS032', @empresaTBS032 output;
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Criar uma tabela com as letras enumeradas do alfabeto
	IF object_id('tempdb.dbo.#Alfabeto') is not null
		drop table #Alfabeto;

	-- A, B, C, D, E, F, G, H, I, J, K, L, M, N, O, P, Q, R, S, T, U, V, W, X, Y, Z
	create table #Alfabeto (letra char(1), numero int)

	insert into #Alfabeto values ('A',1)
	insert into #Alfabeto values ('B',2)
	insert into #Alfabeto values ('C',3)
	insert into #Alfabeto values ('D',4)
	insert into #Alfabeto values ('E',5)
	insert into #Alfabeto values ('F',6)
	insert into #Alfabeto values ('G',7)
	insert into #Alfabeto values ('H',8)
	insert into #Alfabeto values ('I',9)
	insert into #Alfabeto values ('J',10)
	insert into #Alfabeto values ('K',11)
	insert into #Alfabeto values ('L',12)
	insert into #Alfabeto values ('M',13)
	insert into #Alfabeto values ('N',14)
	insert into #Alfabeto values ('O',15)
	insert into #Alfabeto values ('P',16)
	insert into #Alfabeto values ('Q',17)
	insert into #Alfabeto values ('R',18)
	insert into #Alfabeto values ('S',19)
	insert into #Alfabeto values ('T',20)
	insert into #Alfabeto values ('U',21)
	insert into #Alfabeto values ('V',22)
	insert into #Alfabeto values ('W',23)
	insert into #Alfabeto values ('X',24)
	insert into #Alfabeto values ('Y',25)
	insert into #Alfabeto values ('Z',26)

	-- SELECT * FROM #Alfabeto
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Obter localizações do cadastro de produto

	IF object_id('tempdb.dbo.#ItensLocalizados') is not null
		drop table #ItensLocalizados;

	SELECT 
		--A.PROCOD,
		identity(int, 1,1) AS rank, 
		rtrim(ltrim(str(count(*)))) + case when SUM(ESTQTDATU) = 0 then '' else  ' / ' + rtrim(ltrim(str(SUM(ESTQTDATU)))) end as qtdItensSaldoAtual,
		PROLOCFIS as localizacao, 
		SUBSTRING(PROLOCFIS,1,2) as rua, 
		SUBSTRING(PROLOCFIS,3,1) as bloco, 
		SUBSTRING(PROLOCFIS,4,2) as andar, 
		SUBSTRING(PROLOCFIS,6,1) as apto,
		SUM(ESTQTDATU) as saldo, 
		count(*) as qtdItens,
		(SELECT numero from #Alfabeto C (nolock) where C.letra collate database_default = SUBSTRING(A.PROLOCFIS,6,1)) as numero

	INTO #ItensLocalizados
	FROM TBS010 A (NOLOCK) 
	LEFT JOIN TBS032 B (NOLOCK) ON B.PROEMPCOD = @empresaTBS032 AND A.PROCOD = B.PROCOD

	WHERE
	A.PROEMPCOD = @empresaTBS010 AND
	PROLOCFIS <> '' AND 
	ESTLOC = 1 AND 
	LEN(PROLOCFIS) = 6 and 
	ISNUMERIC(SUBSTRING(PROLOCFIS,1,2)) = 1 and
	ISNUMERIC(SUBSTRING(PROLOCFIS,3,1)) = 0 and
	ISNUMERIC(SUBSTRING(PROLOCFIS,4,2)) = 1 and
	ISNUMERIC(SUBSTRING(PROLOCFIS,6,1)) = 0

	group by 
	PROLOCFIS

	ORDER BY 
	SUBSTRING(PROLOCFIS,1,2),
	SUBSTRING(PROLOCFIS,3,1),
	SUBSTRING(PROLOCFIS,4,2) desc, 
	SUBSTRING(PROLOCFIS,6,1)

	-- SELECT * from #ItensLocalizados order by rank 
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Tabela final

	SELECT 
		*, 
		case when numero - 1 = isnull((select numero from #ItensLocalizados B where A.rua = B.rua and A.bloco= B.bloco and A.andar = B.andar and B.numero = A.numero - 1),0)
			then 0
			else 1
		end as errado

	FROM #ItensLocalizados A 

	WHERE 
	rua = case when @cRua = '' then rua else @cRua end AND
	bloco = case when @cBloco = '' then bloco else upper(rtrim(ltrim(@cBloco))) end AND
	andar = case when @cAndar = '' then andar else @cAndar end AND 
	apto = case when @cApto = '' then apto else upper(rtrim(ltrim(@cApto))) end

	order by rank
END