// Procolis admin UI kit — mock data
(function(){
  window.PCAdmin = {
    kpis: [
      { icon:'package_2', tone:'primary', value:'1 284', label:'Colis ce mois', delta:12 },
      { icon:'local_shipping', tone:'green', value:'34', label:'En transit', delta:4 },
      { icon:'schedule', tone:'amber', value:'18', label:'En attente', delta:-6 },
      { icon:'group', tone:'neutral', value:'27', label:'Chauffeurs actifs', delta:2 },
    ],
    parcels: [
      { tracking:'PC-7F3K-2291', client:'Awa Diallo', from:'Abidjan', to:'Bouaké', driver:'Koffi Aka', status:'transit', price:'12 500', date:'27/06 · 08:12' },
      { tracking:'PC-2M9X-7740', client:'Awa Diallo', from:'Abidjan', to:'Yamoussoukro', driver:null, status:'free', price:'6 000', date:'27/06 · 09:40' },
      { tracking:'PC-8K3P-5521', client:'Yao Kouassi', from:'Abidjan', to:'Daloa', driver:null, status:'pending', price:'14 500', date:'27/06 · 10:02' },
      { tracking:'PC-5J1B-3382', client:'Fatou Baki', from:'Abidjan', to:'San-Pédro', driver:'Ibrahim Koné', status:'delivered', price:'18 000', date:'26/06 · 16:30' },
      { tracking:'PC-9D4C-1120', client:'Yao Kouassi', from:'Abidjan', to:'Korhogo', driver:'Sékou Bamba', status:'pickup', price:'22 000', date:'26/06 · 14:11' },
      { tracking:'PC-1A7T-9043', client:'Awa Diallo', from:'Abidjan', to:'Man', driver:null, status:'free', price:'20 000', date:'26/06 · 11:48' },
      { tracking:'PC-3R6Y-4417', client:'Mariam Cissé', from:'Abidjan', to:'Gagnoa', driver:'Koffi Aka', status:'delivering', price:'9 800', date:'26/06 · 09:20' },
    ],
    drivers: [
      { name:'Koffi Aka', vehicle:'Toyota Hiace', rating:'4,9', load:2, status:'online' },
      { name:'Ibrahim Koné', vehicle:'Renault Master', rating:'4,7', load:0, status:'online' },
      { name:'Sékou Bamba', vehicle:'Toyota Hiace', rating:'4,8', load:1, status:'busy' },
      { name:'Adama Touré', vehicle:'Hyundai H1', rating:'4,6', load:0, status:'offline' },
      { name:'Bakary Sanogo', vehicle:'Mercedes Sprinter', rating:'4,9', load:3, status:'busy' },
    ],
    bars: [40,55,48,70,62,80,68,90,75,84,72,95],
  };
})();
