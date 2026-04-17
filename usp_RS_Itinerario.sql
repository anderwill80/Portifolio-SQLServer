/*
====================================================================================================================================================================================
															Script do Report Server
====================================================================================================================================================================================
													Movimenta��es do Produto nos Estoques
====================================================================================================================================================================================
														Hist�rico de altera��es
====================================================================================================================================================================================
Data		Por							Descri��o
**********	********************		********************************************************************************************************************************************
06/11/2024	ANDERSON WILLIAM			- Inclusão dos atributos ITIDATEMI, ITIHOREMI e ITIUSUEMI, no select da tabela TBS109;

08/02/2024	ANDERSON WILLIAM			- Convers�o para Stored procedure
										- Uso da "usp_GetCodigoEmpresaTabela" em vez de "sp_GetCodigoEmpresaTabela", 
										  SQL deixa de verificar SP no BD Master, buscando direto no SIBD
************************************************************************************************************************************************************************************
*/
--create proc [dbo].[usp_RS_Itinerario](
alter proc [dbo].[usp_RS_Itinerario](
	@empcod int,
	@numeroItinerario int
	)
as

begin

	SET NOCOUNT ON;
------------------------------------------------------------------------------------------------------------------------------------------------------------	
	-- Declara��es das variaveis locais
	declare	@empresaTBS109 int,  @empresaTBS142 int			
------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Verificar se a tabela � compartilhada ou exclusiva(Usando a SP com prefixo renomeada para "usp_...")
	exec dbo.usp_GetCodigoEmpresaTabela @empcod, 'TBS109', @empresaTBS109 output;
	exec dbo.usp_GetCodigoEmpresaTabela @empcod, 'TBS002', @empresaTBS142 output;
------------------------------------------------------------------------------------------------------------------------------------------------------------------

	if object_id('tempdb.dbo.#Itinerario') is not null 
	begin 
		drop table #Itinerario
	end 

	select 
	A.ITINUM as numeroItinerario,
	A.ITIDATSAI as hoje,
	A.MOTEMPCOD as empresaMotorista,
	A.MOTCOD as codigoMotorista,
	A.ITICARPLA as placaCarro, 
	ITIHORSAI as horaSaida,
	ITIHORRET as horaChegada,
	A.ITIKMATU as kmSaida,
	A.ITIKMFIN as kmChegada,
	ITIREFINI as inicioAlmoco,
	ITIREFFIN as fimAlmoco,
	A.ITIOBS as observacao,
	case A.ITISTATUS
		when 'A' then 'Aberto'
		when 'F' then 'Finalizado'
		else ''
	end as status,

	B.ITIORDENT as ordem, 
	B.ITIDOCNUM as numeroDocumento, 
	ITICANDEV as canhoto,
	B.ITINUMCXA as caixa,
	rtrim(B.ITINOMDES) as nomeCliente, 
	isnull(B.ITIDELIVE,'') as delivery,
	B.ITIQTDVOL as quantidadeVolume, 
	B.ITITOTDOC as valorDocumento,
	isnull(B.ITIRECENT,'') as receber,
	ITIKMENT as km, 
	ITIHORCHEENT as horaChegadaDocumento,
	ITIHORENT as horaEntregaDocumento,
	ITIHORSAIENT as horaSaidaDocumento, 
	case isnull(B.ITIFORPAG,'')
		when 'D' then 'DINHEIRO. '
		when 'C' then 'CART�O. '
		when 'Q' then 'CHEQUE. '
		when 'O' then 'OUTROS. '
		else ''
	end
	+ rtrim(isnull(B.ITIOBSDOC,'')) as observacaoDocumento,
	Convert(date, ITIDATEMI) as ITIDATEMI,
	ITIHOREMI,
	Rtrim(ITIUSUEMI) ITIUSUEMI

	into #Itinerario
	from TBS109 A (nolock)
	inner join TBS1091 B (nolock) on A.ITIEMPCOD = B.ITIEMPCOD and A.ITINUM = B.ITINUM 

	Where 
	A.ITIEMPCOD	= @empresaTBS109 AND 
	A.ITINUM	= @numeroItinerario

	Order by
	A.ITIEMPCOD,
	A.ITINUM,
	B.ITIORDENT

-- select * from #Itinerario

------------------------------------------------------------------------------------------------------------------------------------------------------------------

	-- Pegar o nome do motorista do itinerario filtrado 

	if object_id('tempdb.dbo.#Motorista') is not null 
	begin 
		drop table #Motorista
	end 

	select 
	MOTEMPCOD as empresaMotorista,
	MOTCOD as codigoMotorista,
	rtrim(MOTNOM) as nomeMotorista

	into #Motorista
	from TBS142 (nolock) 

	Where
	MOTEMPCOD	= @empresaTBS142 AND  
	MOTCOD		= ( select top 1 codigoMotorista from #Itinerario)

	order by 
	MOTEMPCOD,
	MOTCOD

------------------------------------------------------------------------------------------------------------------------------------------------------------------

	-- tabela final 
	select 
	a.*,
	b.nomeMotorista

	from #Itinerario a
	left join #Motorista b on a.empresaMotorista = b.empresaMotorista and a.codigoMotorista = b.codigoMotorista

	order by 
	ordem
End
