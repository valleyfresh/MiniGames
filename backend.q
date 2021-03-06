\p 1234

//////////////////////////////////
////   Client Play Function   ////
/////////////////////////////////

playHand:{[cards] 
	$[.backend.checkTurn[];.backend.turnMsg[];
	//First hand validations
		0=count .backend.turnTable;
			$[.backend.check3D[cards];.backend.firstHand3DMsg[];
			.backend.checkPass[cards];.backend.firstPassMsg[];
			.backend.passInHand[cards];.backend.passInHandMsg[];
			.backend.checkInHand[cards];.backend.notInHandMsg[];
			.backend.roundPlay[cards];.backend.invalidRoundMsg[];
			//Play first hand after passing validations
				[.backend.broadcastPlay[cards];
				.debug.daryl::"first hand";
				.backend.turnTableUpdate[a;cards;(.backend.rankCalc a:.backend.roundDict?count .backend.cardDeck?cards)[cards]];
				.backend.removeCard[cards];
				.backend.broadcastCardNo'[exec user from .backend.connections;count each .backend.hand];
				.backend.sendHand[];
				.backend.nextTurn[]
				]
			];
		//Round hand validations - Run if not first hand
		0<sum -3#exec rankVal from .backend.turnTable;	
			[
			roundHandValidations[cards];
			];
		newRoundValidations[cards]
	]};

roundHandValidations:{[cards]
		//Check if the card is a pass
		$[(1=count .backend.cardDeck?cards)&(max 0=.backend.cardDeck?cards);
			//Playing a pass
			[.backend.broadcastPlay[cards];
			.debug.daryl::"pass turn val";
			.backend.turnTableUpdate[first -1#exec round from .backend.turnTable;cards;0];
			.backend.broadcastCardNo'[exec user from .backend.connections;count each .backend.hand];
			.backend.sendHand[];
			.backend.nextTurn[]
			];
			//Validations if it's a normal hand
			$[.backend.passInHand[cards];.backend.passInHandMsg[];
				.backend.checkInHand[cards];.backend.notInHandMsg[];
				.backend.roundPlay[cards];.backend.invalidRoundMsg[];
				(.backend.rankValCheck .backend.roundDict?count .backend.cardDeck?cards)[cards];.backend.invalidRankValMsg[];
			//Play hand after passing validations
				[.backend.broadcastPlay[cards];
				.backend.turnTableUpdate[a;cards;(.backend.rankCalc a:.backend.roundDict?count .backend.cardDeck?cards)[cards]];
				.backend.removeCard[cards];
				$[.backend.endGame[];
					neg[exec handle from .backend.connections]@\:(0N!;(string first exec user from .backend.connections where i=(first where 0=count each .backend.hand))," is the winner!");
					[.backend.broadcastCardNo'[exec user from .backend.connections;count each .backend.hand];
					.backend.sendHand[];
					.backend.nextTurn[]
					]
				]
				]
			]
		];	
 };

newRoundValidations:{[cards]
	//New round validations - run if not new hand and if 3 passes were played
	$[.backend.passInHand[cards];.backend.passInHandMsg[];
		.backend.checkInHand[cards];.backend.notInHandMsg[];
		.backend.roundPlay[cards];.backend.invalidRoundMsg[];
		//Play new round after passing validations
		[.backend.broadcastPlay[cards];
		.debug.daryl::"new round val";
		.backend.turnTableUpdate[a;cards;(.backend.rankCalc a:.backend.roundDict?count .backend.cardDeck?cards)[cards]];
		.backend.removeCard[cards];
		$[.backend.endGame[];
			neg[exec handle from .backend.connections]@\:(0N!;(string first exec user from .backend.connections where i=(first where 0=count each .backend.hand))," is the winner!");
			[.backend.broadcastCardNo'[exec user from .backend.connections;count each .backend.hand];
			.backend.sendHand[];
			.backend.nextTurn[]
			]
		]
		]
	]  
 };


\d .backend

//////////////////////////////
////   Connection logic   ////
/////////////////////////////

connections:flip `dateTime`user`host`ipAddress`handle`turn!"ZSS*IB"$\:();

.z.po:{[w] $[4>=a:1+exec count i from .backend.connections;
	(`.backend.connections insert .z.Z,.z.u,(.Q.host .z.a;"." sv string "h"$0x0 vs .z.a),w,0b;
	0N!"Connection Established by ",string .z.u);
	neg[w](0N!;"Lobby is full")];
	
	if[1=a:count[.z.W];
        neg[w](0N!;"Please wait for 3 more players to connect before the game commences")];
        
    if[(4>a)&1<a;
        neg[(key .z.W)except w]@\:(0N!;raze"Player ",(string count key[.z.W])," connected");
        $[1=b:4-a;
            neg[key .z.W]@\:(0N!;raze"Please wait for ",(string b)," more player to connect before the game commences");
            neg[key .z.W]@\:(0N!;raze"Please wait for ",(string b)," more players to connect before the game commences")];
        ]
    
    if[4=a;
        neg[key .z.W]@\:(0N!;"All players have connected, the game is commencing...");
	deal[];
	startTurn[];
        ]
    };
	
.z.pc:{[w] delete from `.backend.connections where handle = w;0N!(string .z.u)," has left the Lobby"};

//***   Start game functions   ***//
cardDeck:til[53]!(enlist"pass"),((string 3+til[8]),enlist each"JQKA2")cross"DCHS";

shuffle:{system"S ",string`long$.z.t;
	flip(0N;4)#1+0N?52
	};

deal:{h::exec handle from .backend.connections;
	{neg[x](0N!;y)}'[h;.backend.cardDeck hand::asc each shuffle[]];
	.backend.turnTableInit[]
	};

startTurn:{update turn:max each 1=.backend.hand from `.backend.connections;
	neg[first exec handle from .backend.connections where turn=1b](0N!;"It is your turn")
	};

//Turn table - reinitialised every game and updated when a valid hand is played
turnTableInit:{turnTable::flip `player`handle`round`play`rankVal!"SIS*J"$\:()};
hand:0;

////////////////////
////  Ranking   ////
///////////////////

//***   Card ranking   ***//
suitRank:til[4]!"DCHS";
valueRank:til[13]!(string 3+til[8]),enlist each"JQKA2";
fiveCardRank:(53*1+til[6])!`straight`flush`fullHouse`quads`straightFlush`royalFlush;

//***   Rank calculation   ***//
/Calculating the value of the played hand
singleCalc:{[cards] .backend.cardDeck?cards};
doublesCalc:{[cards] sum(.backend.cardDeck?cards),.backend.suitRank?last each cards};
fiveCardCalc:{[cards] if[any raze(`fullHouse;`quads)=\:(value .backend.fiveCardRank)where .backend.fiveCardVal;
	cards:cards where a=(distinct a)[$[any(3 4)=\:sum(first distinct a)=a:raze -1_'cards;0;1]]
	];
	(max .backend.cardDeck?cards)*last(key .backend.fiveCardRank)where .backend.fiveCardVal
	};

rankCalc:`single`double`fiveCard!(.backend.singleCalc;.backend.doublesCalc;.backend.fiveCardCalc);

/////////////////////////
////   Validations  /////
////////////////////////

//***   General validation   ***//
checkTurn:{not first 1=exec turn from .backend.connections where handle=.z.w};
checkInHand:{[cards] not min(.backend.cardDeck?cards)in .backend.hand[first exec i from .backend.connections where handle=.z.w]};
passInHand:{[cards] (1<count cards)&(any 0=.backend.cardDeck?cards)};

//***   First hand validation   ***//
check3D:{[cards] not max 1=.backend.cardDeck?cards};
checkPass:{[cards] (52=count raze .backend.hand)&(any 0=.backend.cardDeck?cards)};

//***   Round type validations   ***//
singlePlay:{1b};
doublesPlay:{[cards] min(a 0)=a:.backend.valueRank?-1_'cards};
/Global fiveCardVal is used in .backend.rankVal calculations
fiveCardPlay:{[cards] max fiveCardVal::(.backend.straightCheck;
		.backend.flushCheck;
		.backend.fullHouseCheck;
		.backend.quadsCheck;
		.backend.straightFlushCheck;
		.backend.royalCheck)@\:cards
		};

roundDict:`single`double`fiveCard!1 2 5;
roundCheck:`single`double`fiveCard!(.backend.singlePlay;.backend.doublesPlay;.backend.fiveCardPlay);

roundPlay:{[cards] $[(0=count .backend.turnTable)|0=sum -3#exec rankVal from .backend.turnTable;
	$[(a:count .backend.cardDeck?cards) in value .backend.roundDict;
		not(.backend.roundCheck .backend.roundDict?count .backend.cardDeck?cards)[cards];
		1b]; 
	$[(count .backend.cardDeck?cards)=.backend.roundDict a:first -1#exec round from .backend.turnTable;
		not(.backend.roundCheck a)[cards];
		1b]
	]
	};

//***   Five card validations   ***//
straightCheck:{[cards] min 1=1_deltas .backend.valueRank?-1_'cards};
flushCheck:{[cards] min(first a)=a:last each cards};
straightFlushCheck:{[cards] .backend.straightCheck[cards]&.backend.flushCheck[cards]};
royalCheck:{[cards] .backend.straightCheck[cards]&.backend.flushCheck[cards]&50=sum .backend.valueRank?-1_'cards};
fullHouseCheck:{[cards] $[2=count distinct a:.backend.valueRank?-1_'cards;
	any(min=[(sum=[a]@)each distinct a]@)each(3 2;2 3);
	0b
	]
	};
quadsCheck:{[cards] $[2=count distinct a:.backend.valueRank?-1_'cards;
	any(min=[(sum=[a]@)each distinct a]@)each(4 1;1 4);
	0b
	]
	};

//***  Value validation   ***// 
/Ensure that played card value is greater than the previous play
singleRankCheck:{[cards] .backend.singleCalc[cards]<last exec rankVal from .backend.turnTable where rankVal>0};
doublesRankCheck:{[cards] .backend.doublesCalc[cards]<last exec rankVal from .backend.turnTable where rankVal>0};
fiveCardRankCheck:{[cards] .backend.fiveCardCalc[cards]<last exec rankVal from .backend.turnTable where rankVal>0};

rankValCheck:`single`double`fiveCard!(.backend.singleRankCheck;.backend.doublesRankCheck;.backend.fiveCardRankCheck);

//////////////////////////////
///   Validation Messages  ///
/////////////////////////////

invalidNumberMsg:{neg[.z.w](0N!"Invalid number of cards!")};
turnMsg:{neg[.z.w](0N!;"It is not your turn!")};
notInHandMsg:{neg[.z.w](0N!;"Invalid cards!")};
firstPassMsg:{neg[.z.w](0N!;"You cannot pass this turn!")};
passInHandMsg:{neg[.z.w](0N!;"Pass can only be played by itself!")};
firstHand3DMsg:{neg[.z.w](0N!;"First hand needs to have 3D!")};
invalidDoublesMsg:{neg[.z.w](0N!;"Invalid doubles pair!")};
invalidFiveCardMsg:{neg[.z.w](0N!;"Invalid 5 card combo!")};
invalidRoundMsg:{neg[.z.w](0N!;"Invalid play! The current round type is ",string first -1#exec round from .backend.turnTable)};
invalidRankValMsg:{neg[.z.w](0N!;"Hand value is lower than previously played hand!")};

/////////////////////////////////////
////   Post-validation actions   ////
////////////////////////////////////

broadcastPlay:{[cards] neg[h]@\:(0N!;raze(string .z.u)," played ",cards)};
turnTableUpdate:{[round;cards;rankVal] `.backend.turnTable upsert (.z.u;.z.w;round;enlist cards;rankVal)};
//***NOTE: Only run next turn after running remove card function***//
removeCard:{[cards] 
	@[`.backend.hand;
	a;
	{_/[x;y]};
	raze desc(where=[.backend.hand a:first exec i from .backend.connections where turn=1]@)each .backend.cardDeck?cards
	]};
broadcastCardNo:{neg[h]@\:(0N!;raze (string x)," has ",(string y)," cards left!")};
nextTurn:{update turn:-1 rotate turn from `.backend.connections;
	neg[exec handle from .backend.connections where turn=0]@\:(0N!;raze"It is ",string .z.u,"'s turn");
	neg[first exec handle from .backend.connections where turn=1](0N!;"It is your turn");
	if[0=sum -3#exec rankVal from .backend.turnTable;
		neg[first exec handle from .backend.connections where turn=1](0N!;"3 players played pass. You can start a new round!")]
		};
sendHand:{{neg[x](0N!;y)}'[h;.backend.cardDeck hand]};
endGame:{any 0=count each .backend.hand};
